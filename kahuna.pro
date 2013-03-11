PRO makelimbstrips, thresh, xstrips, ystrips, region=region, time=time
;+
;   :Description:
;       Makes limb strips from full-length strips
;
;   :Params:
;       thresh : out, required, type=float
;           Threshold used to select pixels
;       xstrips : out, required, type=structure
;           Structure containing row strips
;       ystrips : out, required, type=structure
;           Structure containing column strips
;
;   :Keywords:
;       region: in, required, type=integer, default=1
;           Which sun out of the three to find the center of. Defaults to the brightest sun
;       time : in, optional
;           Prints the elapsed time
;-

; IF n_elements(region) EQ 0 THEN region = 1
IF region EQ !null THEN region = 1

COMMON vblock, wholeimage, scan_width, sundiam, nstrips, order, ministrip_length, file, crop_box, scan_radius

; Going through and doing a little commenting, think I forgot how this works:

makestrips, thresh, c4xstrips, c4ystrips, region=region, time=time

start = SYSTIME(1,/seconds)

ministrip_side_buffer = byte(ministrip_length)/2 
; have to byte it since we read the ministrip_length as a float

; Contains coordinates of chord enpoints
rowchord_endpoints = fltarr(2,n_elements(c4xstrips))
colchord_endpoints = fltarr(2,n_elements(c4ystrips))
;   Seeing where the array starts to be greater than the thresh
FOR i = 0,n_elements(c4ystrips)-1 DO BEGIN
    col_where = where(c4ystrips[i].ARRAY GT thresh)
    ; beginning of chord
    colchord_endpoints[0,i] = col_where[0]
    ; end of chord
    colchord_endpoints[1,i] = col_where[-1]
ENDFOR

FOR i = 0,n_elements(c4xstrips) -1 DO BEGIN
    row_where = where(c4xstrips[i].ARRAY GT thresh)
    rowchord_endpoints[0,i] = row_where[0]
    rowchord_endpoints[1,i] = row_where[-1]
ENDFOR

; Preallocating the array, replicating it by the number of strips there are
xstrips = REPLICATE({ROWINDEX:0, BEGINDEX:0, ENDINDEX:0, $
        STARTPOINTS:BYTARR(ministrip_length), $
        ENDPOINTS:BYTARR(ministrip_length), $
        xoffset:c4xstrips.xoffset},N_ELEMENTS(c4xstrips))
ystrips = REPLICATE({COLINDEX:0, BEGINDEX:0, ENDINDEX:0, $
        STARTPOINTS:BYTARR(ministrip_length), $
        ENDPOINTS:BYTARR(ministrip_length), $
        yoffset:c4ystrips.yoffset},N_ELEMENTS(c4ystrips))

;Filling out structure with cut-down strip information
FOR i = 0,N_ELEMENTS(c4xstrips) - 1 DO BEGIN
    xstrips[i].ROWINDEX     = c4xstrips[i].ROWINDEX
    ; If there is no strip that cuts through the sun, set things to 0
    IF rowchord_endpoints[0,i] EQ -1 THEN BEGIN
        xstrips[i].STARTPOINTS  = BYTARR(ministrip_length) 
        xstrips[i].BEGINDEX     = 0
    ENDIF ELSE BEGIN
        ; STARTPOINTS is the cut down strip with length = ministrip_length and contains
        ; the indices from rowchord_endpoints[0,i] +/- ministrip_side_buffer
        ; print,region
        ; stop
        xstrips[i].STARTPOINTS  = $
        ; IF chord is too long, it tries to crop from outside of image file
            (c4xstrips[i].ARRAY)[rowchord_endpoints[0,i]-ministrip_side_buffer:$
            rowchord_endpoints[0,i]+ministrip_side_buffer]   
        ; BEGINDEX is the index of the strip where it begins. 
        ; e.g., the array is 5 long, starts from index 9 and is centered around index 11
        xstrips[i].BEGINDEX     = FIX(rowchord_endpoints[0,i] - ministrip_side_buffer)
    ENDELSE

    IF rowchord_endpoints[1,i] EQ -1 THEN BEGIN
        xstrips[i].ENDPOINTS    = BYTARR(ministrip_length)
        xstrips[i].ENDINDEX    = 0
    ENDIF ELSE BEGIN
        xstrips[i].ENDPOINTS  = $
            (c4xstrips[i].ARRAY)[rowchord_endpoints[1,i]-ministrip_side_buffer:$
            rowchord_endpoints[1,i]+ministrip_side_buffer]   
        xstrips[i].ENDINDEX     = FIX(rowchord_endpoints[1,i] - ministrip_side_buffer)
    ENDELSE
ENDFOR


FOR k = 0,N_ELEMENTS(c4ystrips) - 1 DO BEGIN
    ystrips[k].COLINDEX     = c4ystrips[k].COLINDEX
    IF colchord_endpoints[0,k] EQ -1 THEN BEGIN
        ystrips[k].STARTPOINTS  = BYTARR(ministrip_length) 
        ystrips[k].BEGINDEX     = 0
    ENDIF ELSE BEGIN 
        ystrips[k].STARTPOINTS  = (c4ystrips[k].ARRAY)[colchord_endpoints[0,k]- $
            ministrip_side_buffer:colchord_endpoints[0,k]+ministrip_side_buffer]
        ystrips[k].BEGINDEX     = FIX(colchord_endpoints[0,k] - ministrip_side_buffer)
    ENDELSE

    IF colchord_endpoints[1,k] EQ -1 THEN BEGIN
        ystrips[k].ENDPOINTS    = BYTARR(ministrip_length) 
        ystrips[k].ENDINDEX     = 0        
    ENDIF ELSE BEGIN
        ystrips[k].ENDPOINTS    = (c4ystrips[k].ARRAY)[colchord_endpoints[1,k]- $
        ministrip_side_buffer:colchord_endpoints[1,k]+ministrip_side_buffer]
        ystrips[k].ENDINDEX     = FIX(colchord_endpoints[1,k] - ministrip_side_buffer) 
    ENDELSE
ENDFOR


finish = SYSTIME(1,/seconds)

IF KEYWORD_SET(time) THEN  print,'Elapsed Time for makelimbstrips: ', $
    STRCOMPRESS(finish-start,/rem),' seconds'
RETURN
END


;**************************************************************************************************
;*                                                                                                *
;**************************************************************************************************

 
FUNCTION quickmask, input_image, thresh
;+
;   :Description:
;       Finds center of mask where pixels are above a given threshold
;
;   :Params:
;       input_image : in, required, type=byte
;           2D array of pixels to mask with threshold
;       thresh : in, required, type=float
;           Threshold used to select pixels
;-


a = input_image[SORT(input_image)]
niceimage = a[0:0.99*(N_ELEMENTS(a)-1)]
; Eliminating the highest 1% of data
IF thresh eq !null then thresh = 0.25*MAX(niceimage)
; IF n_elements(thresh) EQ 0 THEN thresh = 0.25*MAX(image)

s = SIZE(input_image,/dimensions)
n_col = s[0]
n_row = s[1]

suncheck = input_image gt thresh

xpos = TOTAL( TOTAL(suncheck, 2) * INDGEN(n_col) ) / TOTAL(suncheck)
ypos = TOTAL( TOTAL(suncheck, 1) * INDGEN(n_row) ) / TOTAL(suncheck)
RETURN, {xpos:xpos,ypos:ypos}
END


;**************************************************************************************************
;*                                                                                                *
;**************************************************************************************************


FUNCTION whichcropmethod, region
;+
;   :Description:
;       Crops differently according to which region is selected. 
;
;   :Params:
;       region : in, required, type=integer
;           1) main sun
;           2) 50% brightness sun
;           3) 25% brightness sun
;-
COMMON vblock, wholeimage, scan_width, sundiam, nstrips, order, ministrip_length, file, crop_box, scan_radius

; stop
crop_box = BYTE(crop_box)
a = wholeimage[SORT(wholeimage)]
niceimage = a[0:0.99*(N_ELEMENTS(a)-1)]

; thresh = 0.65*max(WHOLEimage)
thresh = 0.65*max(niceimage)
ducks = quickmask(wholeimage,thresh)

image = wholeimage[ducks.xpos-crop_box:ducks.xpos+crop_box,ducks.ypos-crop_box:ducks.ypos+crop_box]

mainxpos = ducks.xpos
mainypos = ducks.ypos
xoffset = ducks.xpos-crop_box
yoffset = ducks.ypos-crop_box

IF REGION NE 1 THEN BEGIN
    circscancrop, mainxpos, mainypos, image, thresh, xpos, ypos, xoffset, yoffset, region=region, time=time
ENDIF

; There is a strong fiducial at image[*,53], but it's not on the limb. It's pretty darn close though. 
; Now, need to replicate those conditions

; plot,image[40,*],/nodata

; i=0
; while get_kbrd(0) EQ '' do BEGIN
; oplot, image[*,i]
; wait,.2
; i++
; ENDWHILE
; plot,image[0:20,53]
; stop

; stop
RETURN,{image:image, xoffset:xoffset, yoffset:yoffset, thresh:thresh}
END


;**************************************************************************************************
;*                                                                                                *
;**************************************************************************************************


PRO makestrips, thresh, xstrips, ystrips, region=region, time=time
;+
;   :Description:
;       Only saves 5 strips centered around the solar diameter to reduce the amount of limb-
;           darkened pixels and to make the polynomial-fitted limbs more-or-less look similar. 
;
;   :Params:
;   thresh : out, required, type=float
;       Threshold used to select pixels
;   xstrips : out, required, type=structure
;       Structure containing row strips
;   ystrips : out, required, type=structure
;       Structure containing column strips
;
;   :Keywords:
;   region : in, required, type=integer, default=1
;       Which sun out of the three to find the center of. Defaults to the brightest sun
;   time : in, optional
;       Prints elapsed time
;-

; IF n_elements(region) EQ 0 THEN region = 1
IF region eq !null then region = 1

COMMON vblock, wholeimage, scan_width, sundiam, nstrips, order, ministrip_length, file, crop_box, scan_radius

struct = whichcropmethod(region)
ducks = quickmask(struct.image)
thresh = struct.thresh

start = SYSTIME(1,/seconds)

animage = struct.image
s = size(animage,/dimensions)
length = s[0]
height = s[1]

rowchord_endpoints = fltarr(2,nstrips)
colchord_endpoints = fltarr(2,nstrips)

xstrips = REPLICATE({ROWINDEX:0,ARRAY:bytarr(length),xoffset:struct.xoffset},nstrips)
ystrips = REPLICATE({COLINDEX:0,ARRAY:bytarr(height),yoffset:struct.yoffset},nstrips)


; FOR i = 0,nstrips - 1 DO BEGIN
;     xstrips[i].ROWINDEX = i
;     xstrips[i].ARRAY = animage[*, round(ducks.xpos)+(i-nstrips/2)*scan_width]
; ENDFOR

; FOR k = 0,nstrips - 1 DO BEGIN
;     ystrips[k].COLINDEX = k
;     ystrips[k].ARRAY = animage[round(ducks.ypos)+(k-nstrips/2)*scan_width,*]
; ENDFOR

;Combining these two for loops
FOR i = 0,nstrips - 1 DO BEGIN
    xstrips[i].ROWINDEX = i
    xstrips[i].ARRAY = animage[*, round(ducks.xpos)+(i-nstrips/2)*scan_width]
    ystrips[i].COLINDEX = i
    ystrips[i].ARRAY = animage[round(ducks.ypos)+(i-nstrips/2)*scan_width,*]
ENDFOR

finish = SYSTIME(1,/seconds)
IF KEYWORD_SET(time) THEN  print,'Elapsed Time for makestrips: ', $
    strcompress(finish-start,/rem),' seconds'
RETURN
END


;**************************************************************************************************
;*                                                                                                *
;**************************************************************************************************


PRO circscancrop, mainxpos, mainypos, image, thresh, xpos, ypos, xoffset, yoffset, region=region, $
     time=time
;+
;   :Description: 
;       Quickly finds the center of the main sun, scans in a circle, and locates the two secondary 
;       suns' centers. Crops either of the secondary suns based on what region specified.
;
;   :Params:
;       mainxpos : in, required
;           X position of 100% brightness sun to scan in a circle around
;       mainypos : in, required
;           Y position of 100% brightness sun to scan in a circle around
;       image : out, required
;           Cropped area
;       thresh : out, required, type=float
;           Threshold used in finding center
;       xpos : out, required, type=float
;           Computed X position of center
;       ypos : out, required, type=float
;           Computed Y position of center
;       xoffset : out, required
;           X offset of cropped region's bottom left corner
;       yoffset : out, required
;           Y offset of cropped region's bottom left corner
;
;   :Keywords:
;       region: in, required, type=integer, default=1
;           Which sun out of the three to find the center of. Defaults to the brightest sun
;       time : in, optional
;           Print the elapsed time
;-

COMPILE_OPT idl2 
ON_ERROR,2

COMMON vblock, wholeimage, scan_width, sundiam, nstrips, order, ministrip_length, file, crop_box, scan_radius
start = SYSTIME(1,/s)

arr=(findgen(360) + 90)*!dtor
; only adding 90 so that it starts from 12 o'clock assuming there is
; no dim sun at that location

radius = 129  ; well this is rather arbitrary
r2bit = 2

; The way we have it scanning now is if it doesn't find the aux sun, it scans at a radius interval of 
; 10 so that it looks at the r_orig - interval and r_orig + interval radii. Now, what if the sun isn't there? 
loop: BEGIN
    IF file EQ 'dimsun1.fits' THEN radius = BYTE(scan_radius)
    ; print,r2bit,' Beginning r2bit'
    ; print,region
    r2 = radius + 10*r2bit ;10 is an arbitrary number, can be anything, really

    x = radius*cos(arr) + mainxpos
    y = radius*sin(arr) + mainypos
    x2 = r2*cos(arr) + mainxpos
    y2 = r2*sin(arr) + mainypos

    ; Have to use .3 instead of .25 for dimsun2, don't know why

    sorted =  wholeimage[sort(wholeimage)]
    thresh = 0.3*max( sorted[0:.99*(n_elements(sorted)-1)] )
    ; ^^
    ; Well this doesn't work.
    
    thresh = 0.3*max(wholeimage)
    ; Alright, for some reason, clipping out the top 1% changes the thresh from 53.7 to 64.5
    ; which makes the centerx,centery go from 337,76 (correct)
    ; to
    ; 144,19 (so, so wrong)
    ; now, how to deal with it?

    pri_scan = where(wholeimage[x,y] GT thresh,pri_where)
    aux_scan = where(wholeimage[x2,y2] GT thresh,aux_where)

    ; print,aux_where, ' aux_where before if statement'
    IF aux_where NE 0 THEN BEGIN
    ; stop
        in_inner  = (where(wholeimage[x,y]     GT thresh))[0] - 10
        in_outer  = (where(wholeimage[x2,y2]   GT thresh))[0] - 10
        out_inner = (where(wholeimage[x,y]     GT thresh))[-1] + 10
        out_outer = (where(wholeimage[x2,y2]   GT thresh))[-1] + 10
    ENDIF ELSE BEGIN
        ; print,r2bit,aux_where
        r2bit*=-1
        ; print,r2bit
        GOTO, loop
    ENDELSE
END

r2bit = 2
r2 = radius + 10*r2bit
x2 = r2*cos(arr) + mainxpos
y2 = r2*sin(arr) + mainypos

otherloop: BEGIN
    IF REGION EQ 3 THEN BEGIN
    ; print,region,' Region'
        thresh = 0.2*max(wholeimage) ;dimsun2 works if i set the thresh to .2 instead of .15
        ; The other sun is so dim that weird parts are being picked up. How to fix? Is being dim a problem?


        sorted =  wholeimage[sort(wholeimage)]
        thresh = 0.2*max( sorted[0:.99*(n_elements(sorted)-1)] )
        ; ^^
        ; Well this doesn't work.
    
        thresh = 0.2*max(wholeimage)


        ; For showing where the circles are
        ; stop
        ; wholeimage[x[in_inner:out_inner],y[in_inner:out_inner]] = 0
        ; wholeimage[x2[in_outer:out_outer],y2[in_outer:out_outer]] = 0
        
        ; check to make sure we're scanning at the right radius
        n_check = where((wholeimage[x2,y2] GT thresh) EQ 1,n_where)

        IF n_where NE 0 THEN BEGIN
            ; in_inner  = (where(wholeimage[x,y]     GT thresh))[0] - 10
            ; in_outer  = (where(wholeimage[x2,y2]   GT thresh))[0] - 10
            ; out_inner = (where(wholeimage[x,y]     GT thresh))[-1] + 10
            ; out_outer = (where(wholeimage[x2,y2]   GT thresh))[-1] + 10
            part1 = wholeimage[x[0:in_inner],y[0:in_inner]]
            part2 = wholeimage[x[out_inner:N_ELEMENTS(x)-1],y[out_inner:N_ELEMENTS(x)-1]]
            part1b = wholeimage[x2[0:in_outer],y2[0:in_outer]]
            part2b = wholeimage[x[out_outer:N_ELEMENTS(x)-1],y[out_outer:N_ELEMENTS(x)-1]]
            ;This way we don't alter the original image

            in_inner  = (where([part1,part2] gt thresh))[0] - 10
            out_inner = (where([part1,part2] gt thresh))[-1] - 10
            in_outer  = (where([part1b,part2b] gt thresh))[0] - 10
            out_outer = (where([part1b,part2b] gt thresh))[-1] - 10

; stop
            ; in_inner  = (where(wholeimage[x,y]     GT thresh))[0] - 10
            ; in_outer  = (where(wholeimage[x2,y2]   GT thresh))[0] - 10
            ; out_inner = (where(wholeimage[x,y]     GT thresh))[-1] + 10
            ; out_outer = (where(wholeimage[x2,y2]   GT thresh))[-1] + 10
        ENDIF ELSE BEGIN
            ; print,r2bit,n_where
            ; stop
            r2bit*=-1
            GOTO, otherloop
        ENDELSE

        ; Setting this to 0 actually messes up fitting. use only to show what pixels are being circscanned
        ; wholeimage[x[in_inner:out_inner],y[in_inner:out_inner]] = 0
        ; wholeimage[x2[in_outer:out_outer],y2[in_outer:out_outer]] = 0

    ENDIF
END

centerangle = !dtor*(90 + mean([in_inner,out_inner]))
centerx = mainxpos + radius*cos(centerangle)
centery = mainypos + radius*sin(centerangle)

; What is this arbitrary cropping value
; stop

crop_box = BYTE(crop_box)
image = wholeimage[centerx-crop_box:centerx+crop_box,centery-crop_box:centery+crop_box]
xoffset = centerx-crop_box
yoffset = centery-crop_box

finish = SYSTIME(1,/s)
IF KEYWORD_SET(time) THEN print, 'getstruct took: '+strcompress(finish-start)+$
    ' seconds'
RETURN
END


;**************************************************************************************************
;*                                                                                                *
;**************************************************************************************************


PRO limbfit, thresh, xpos, ypos, plot=plot, region=region, time=time
;+
;   :Description:
;       Uses the data from makelimbstrips and fits an n-th order polynomial to the limb to find where
;       it crosses the threshold.
;
;   :Params:
;       thresh : out, required, type=float
;           Threshold used to select pixels
;       xpos : out, required, type=float
;           X center
;       ypos : out, required, type=float
;           Y center
;
;   :Keywords:
;       region : in, required, type=integer, default=1
;           Which sun out of the three to find the center of. Defaults to the brightest sun
;       plot : in, optional
;           Makes some nice plots
;       time : in, optional
;           Prints the elapsed time
;-

; IF n_elements(region) EQ 0 THEN region = 1
if region eq !null then region = 1

COMMON vblock, wholeimage, scan_width, sundiam, nstrips, order, ministrip_length, file, crop_box, scan_radius

; Run the program to get our structures
makelimbstrips, thresh, xstrips, ystrips, region=region, time=time

start = SYSTIME(1,/seconds)

ministrip_side_length = ministrip_length/2
xlen    = 0
xsum    = 0
xnum    = 0   
ylen    = 0
ysum    = 0
ynum    = 0
xarr    = findgen(n_elements(xstrips[4].STARTPOINTS))
yarr    = findgen(n_elements(ystrips[4].STARTPOINTS))
tx      = findgen(n_elements(xstrips[4].STARTPOINTS) * 1000)/100
ylenarr = findgen(n_elements(ystrips))
xlenarr = findgen(n_elements(xstrips))

;Deal with rows
FOR n=0,n_elements(xstrips)-1 DO BEGIN
    ; Using fz_roots instead of SPLINE interpolating. Saving lines and making code more readable


; ; Since there are no limb profiles with fiducials, I'll just make one up

    ; a = float((xstrips[n].STARTPOINTS))
    ; b=a
    ; (a[3])*=.9
    ; (a[4])*=.8
    ; (a[5])*=.45
    ; (a[6])*=.5
    ; (a[7])*=.7
    ; (a[8])*=.9

    ; startresult     = reform(poly_fit(xarr,a,order))
    ; corrstartresult = reform(poly_fit(xarr,b,order))

    ; xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2,tx)
    ; corrxtmp = SPLINE(xarr,corrstartresult[0] + corrstartresult[1]*xarr + corrstartresult[2]*xarr^2,tx)
    ; ; atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2,tx)
    
    ; plot,xarr+xstrips[n].BEGINDEX,a,xs=3,ys=3,title='Limb Profile',$
    ;     xtitle='Pixel indices of TOTAL strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    ; oplot,tx+xstrips[n].BEGINDEX,xtmp,linestyle=1
    ; oplot,xarr+xstrips[n].BEGINDEX,b,linestyle=4
    ; oplot,tx+xstrips[n].BEGINDEX,corrxtmp,linestyle=5
    ; hline,thresh,linestyle=2
    ; legend,['Actual Data Values','SPLINEd Data'],linestyle=[0,1],/bottom,/right,charsize=2

;     ; Somewhat hard to make poly_fit fuck up when limbfitting even when I'm forcing fiducials
;     ; Perhaps I don't know what they actually look like?



    startresult     = reform(poly_fit(xarr,xstrips[n].STARTPOINTS,order))
    endresult       = reform(poly_fit(xarr,xstrips[n].ENDPOINTS,order))

    ; xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2,tx)
    ; atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2,tx)
    
    ; window,2
    ; plot,xarr+xstrips[n].BEGINDEX,xstrips[n].startpoints,xs=3,ys=3,title='Limb Profile',$
    ;     xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    ; oplot,tx+xstrips[n].BEGINDEX,xtmp,linestyle=1
    ; hline,thresh,linestyle=2
    ; legend,['Actual Data Values','SPLINEd Data'],linestyle=[0,1],/bottom,/right,charsize=2

    ; window,0
    ; plot,xarr+xstrips[n].ENDINDEX,xstrips[n].ENDPOINTS,xs=3,ys=3,title='Limb Profile',$
    ;     xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    ; oplot,tx+xstrips[n].ENDINDEX,atmp,linestyle=1
    ; hline,thresh,linestyle=2
    ; legend,['Actual Data Values','SPLINEd Data'],linestyle=[0,1],/bottom,/left,charsize=2

    ; Solving for roots but want to include threshold value
    startresult[0]  -=thresh
    endresult[0]    -=thresh

    IF xstrips[n].BEGINDEX GT 0 THEN BEGIN
        ; Get roots (complex)
        begroots    = fz_roots(startresult)

        ; print,begroots

        ; Take only roots with no imaginary components
        begusable   = (real_part(begroots))[where(imaginary(begroots) eq 0.)]
        ; Find smallest root (apparently I have to choose the smaller one)
        ; Or i can find the midpoints using the other two roots then take the average of the two,
        ; that way works too, but why would I do that?
        begusable   = (begusable[where(begusable gt 0)])[0]
        stripbeg    = xstrips[n].BEGINDEX + begusable
    ENDIF ELSE BEGIN
        begusable   = 0
        stripbeg    = 0
    ENDELSE

    IF xstrips[n].ENDINDEX GT 0 THEN BEGIN
        endroots    = fz_roots(endresult)
        endusable   = (real_part(endroots))[where(imaginary(endroots) eq 0.)]
        endusable   = (endusable[where(endusable gt 0)])[0]
        stripend    = xstrips[n].ENDINDEX + endusable
    ENDIF ELSE BEGIN
        endusable   = 0
        stripend    = 0
    ENDELSE

    ; Stick the midpoints in an array to take the mean of later
    xlenarr[n] = mean([[stripend],[stripbeg]])
ENDFOR    

FOR n=0,n_elements(ystrips)-1 DO BEGIN
    startresult     = reform(poly_fit(yarr,ystrips[n].STARTPOINTS,order))
    endresult       = reform(poly_fit(yarr,ystrips[n].ENDPOINTS,order))

;     ytmp = SPLINE(yarr,startresult[0] + startresult[1]*yarr + startresult[2]*yarr^2,tx)
;     btmp = SPLINE(yarr,endresult[0] + endresult[1]*yarr + endresult[2]*yarr^2,tx)
    
;     window,3
;     plot,yarr+ystrips[n].BEGINDEX,ystrips[n].startpoints,xs=3,ys=3,title='Limb Profile',$
;         xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(ytmp)]
;     oplot,tx+ystrips[n].BEGINDEX,ytmp,linestyle=1
;     hline,thresh,linestyle=2
;     legend,['Actual Data Values','SPLINEd Data'],linestyle=[0,1],/bottom,/right,charsize=2

;     window,1
;     plot,yarr+ystrips[n].ENDINDEX,ystrips[n].ENDPOINTS,xs=3,ys=3,title='Limb Profile',$
;         xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(ytmp)]
;     oplot,tx+ystrips[n].ENDINDEX,btmp,linestyle=1
;     hline,thresh,linestyle=2
;     legend,['Actual Data Values','SPLINEd Data'],linestyle=[0,1],/bottom,/left,charsize=2
; stop
    startresult[0]  -=thresh
    endresult[0]    -=thresh

    IF ystrips[n].BEGINDEX GT 0 THEN BEGIN
        begroots    = fz_roots(startresult)
        begusable   = (real_part(begroots))[where(imaginary(begroots) eq 0.)]
        begusable   = (begusable[where(begusable gt 0)])[0]
        stripbeg    = ystrips[n].BEGINDEX + begusable
    ENDIF ELSE BEGIN
        begusable   = 0
        stripbeg    = 0
    ENDELSE

    IF ystrips[n].ENDINDEX GT 0 THEN BEGIN
        endroots    = fz_roots(endresult)
        endusable   = (real_part(endroots))[where(imaginary(endroots) eq 0.)]
        endusable   = (endusable[where(endusable gt 0)])[0]
        stripend    = ystrips[n].ENDINDEX + endusable
        
    ENDIF ELSE BEGIN
        endusable   = 0
        stripend    = 0
    ENDELSE

    ylenarr[n] = mean([[stripend],[stripbeg]])
ENDFOR    

; Get the midpoint of the chords
xpos = mean(xlenarr[where(xlenarr ne 0)]) + (xstrips.xoffset)[0]
ypos = mean(ylenarr[where(ylenarr ne 0)]) + (ystrips.yoffset)[0]

IF KEYWORD_SET(plot) THEN BEGIN
    wn = 3
    startresult = poly_fit(xarr,xstrips[wn].STARTPOINTS,order)
    endresult = poly_fit(xarr,xstrips[wn].ENDPOINTS,order)

    CASE order OF
    1: BEGIN
        xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr,tx)
        atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr,tx)
        END
    2: BEGIN
        xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2,tx)
        atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2,tx)
        END
    3: BEGIN
        xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3,tx)
        atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3,tx)
        END
    4: BEGIN
        xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4,tx)
        atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4,tx)
        END
    5: BEGIN
        xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5,tx)
        atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5,tx)
        END    
    6: BEGIN
        xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5 + $
                startresult[6]*xarr^6,tx)
        atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5 + $
                endresult[6]*xarr^6,tx)
        END
    7: BEGIN
        xtmp = SPLINE(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5 + $
                startresult[6]*xarr^6 + startresult[7]*xarr^7,tx)
        atmp = SPLINE(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5 + $
                endresult[6]*xarr^6 + endresult[7]*xarr^7,tx)
        END
    ENDCASE

    ; A pretty plot for Nicole
    window,2
    ; set_plot,'ps'
    ; device,filename=file+'part1'+'.ps',/encapsulated
    plot,xarr+xstrips[wn].BEGINDEX,xstrips[wn].startpoints,xs=3,ys=3,title='Limb Profile',$
        xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    oplot,tx+xstrips[wn].BEGINDEX,xtmp,linestyle=1
    hline,thresh,linestyle=2
    legend,['Actual Data Values','SPLINEd Data'],linestyle=[0,1],/bottom,/right,charsize=2
    ; device,/close
    ; set_plot,'x'
    window,0
    ; set_plot,'ps'
    ; device,filename=file+'part2'+'.ps',/encapsulated
    plot,xarr+xstrips[wn].ENDINDEX,xstrips[wn].ENDPOINTS,xs=3,ys=3,title='Limb Profile',$
        xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    oplot,tx+xstrips[wn].ENDINDEX,atmp,linestyle=1
    hline,thresh,linestyle=2
    legend,['Actual Data Values','SPLINEd Data'],linestyle=[0,1],/bottom,/left,charsize=2
    ; device,/close
    ; set_plot,'x'
ENDIF

finish = SYSTIME(1,/seconds)

IF KEYWORD_SET(time) THEN  print,'Elapsed Time for limbfit: ',strcompress(finish-start,/rem),' seconds'
RETURN
END


;**************************************************************************************************
;*                                                                                                *
;**************************************************************************************************


PRO getstruct, struct, time=time
;+
;   :Description:
;       Finds the centers of a triple-sun image and loads all relevant information
;       including offsets and angles into a new structure.
;
;   :Params:
;       struct : out, required, type=structure
;           Structure containing the centers and cropped images of all 3 suns
;
;   :Keywords:
;       time: in, optional
;           Outputs how much time the program takes
;-
COMPILE_OPT idl2 
ON_ERROR,2

COMMON vblock, wholeimage, scan_width, sundiam, nstrips, order, ministrip_length, file

start = SYSTIME(1,/s)


center1 = {center1,xpos:0d,ypos:0d,thresh:0d}
center2 = {center2,xpos:0d,ypos:0d,thresh:0d}
center3 = {center3,xpos:0d,ypos:0d,thresh:0d}

limbfit, thresh, xpos, ypos, plot=plot, region=1, time=time
center1.xpos = xpos
center1.ypos = ypos
center1.thresh = thresh

limbfit, thresh, xpos, ypos, plot=plot, region=2, time=time
center2.xpos = xpos
center2.ypos = ypos
center2.thresh = thresh

limbfit, thresh, xpos, ypos, plot=plot, region=3, time=time
center3.xpos = xpos
center3.ypos = ypos
center3.thresh = thresh


theta = !radeg*atan((center3.ypos - center2.ypos)/(center3.xpos - center2.xpos))
hypot = sqrt((center3.ypos - center2.ypos)^2 + (center3.xpos - center2.xpos)^2)
offset = ((center1.xpos - center2.xpos)*(center3.ypos - center2.ypos) - $
    (center1.ypos - center2.ypos)*(center3.xpos - center2.xpos))/hypot

struct = {KAHUNA, center1:center1, center2:center2, center3:center3, $
    theta:theta, offset:offset}
finish = SYSTIME(1,/s)
IF KEYWORD_SET(time) THEN print, 'getstruct took: '+strcompress(finish-start)+$
    ' seconds'
RETURN
END


;**************************************************************************************************
;*                                                                                                *
;**************************************************************************************************


; docformat = 'rst'
;
;+
; NAME: 
;   KAHUNA
;
; PURPOSE:
;   Finds the center of 3 suns in a single image. Currently limited to a .bmp test image. Instead
;   of scanning rows to crop, scans in a circle. Using solar centers, identifies fiducial positions.
;
; :Author:
;   JEREN SUZUKI::
;
;       Space Sciences Laboratory
;       7 Gauss Way
;       Berkeley, CA 94720 USA
;       E-mail: jsuzuki@ssl.berkeley.edu
;-

; PRO kahuna, file, time=time
;+
;   :Description:
;       This version uses limb fitting opposed to masking (tricenter). 
;
;   :Params:
;
;   :Keywords:
;       time: in, optional
;           Outputs how much time the program takes
;
;   :TODO: 
;       Find and ISOLATE fiducials, not just mask them out
;
;       Ignore center if sun is too close to edge (or if when cropping, we cro outside wholeimage)
;
;       Use 25% of median(image)
;
;       Make sure program doesn't freak out when sun isn't in POV
;       
;-
COMPILE_OPT idl2 
ON_ERROR,2

start=SYSTIME(1,/s)

; profiler,/system
; profiler

COMMON vblock, wholeimage, scan_width, sundiam, nstrips, order, ministrip_length, file, crop_box, scan_radius
file = 'dimsun1.fits'
readcol,'pblock.txt',var,num,format='A,F',delimiter=' '
    for i=0,N_ELEMENTS(var)-1 do (SCOPE_VARFETCH(var[i],/enter,level=0))=num[i]

wholeimage = mrdfits(file)

getstruct, struct, time=time

; profiler,/report,data=data
; profiler,/reset,/clear

; print,data[sort(-data.time)],format='(A-20, I7, F12.5, F10.5, I9)'

print,'Main sun x pos:',struct.center1.xpos
print,'Main sun y pos:',struct.center1.ypos
print,'50% sun x pos: ',struct.center2.xpos
print,'50% sun y pos: ',struct.center2.ypos
print,'25% sun x pos: ',struct.center3.xpos
print,'25% sun y pos: ',struct.center3.ypos

; wholeimage2 = wholeimage
; wholeimage3 = wholeimage

; wholeimage[struct.center1.xpos,*]=20
; wholeimage[*,struct.center1.ypos]=20
; wholeimage2[struct.center2.xpos,*]=20
; wholeimage2[*,struct.center2.ypos]=20
; wholeimage3[struct.center3.xpos,*]=20
; wholeimage3[*,struct.center3.ypos]=20

; ; window,0
; ; cgimage,wholeimage,/k,output=strmid(file,0,7)+'_'+'region1.png'
; ; ; window,2
; ; cgimage,wholeimage2,/k,output=strmid(file,0,7)+'_'+'region2.png'
; ; ; window,3
; ; cgimage,wholeimage3,/k,output=strmid(file,0,7)+'_'+'region3.png'

; window,0
; cgimage,wholeimage,/k
; window,2
; cgimage,wholeimage2,/k
; window,3
; cgimage,wholeimage3,/k

; Here we make the assumption that the darker regions are linearly darker so we can just divide by 2 and 4
; Works pretty well
; wholeimage = mrdfits(file)
ideal = BYTSCL( READ_TIFF('plots_tables_images/dimsun_ideal.tiff',channels=1) )
crop = wholeimage[struct.center1.xpos-rad:struct.center1.xpos+rad,$
    struct.center1.ypos-rad:struct.center1.ypos+rad]

icrop = ideal[struct.center1.xpos-rad:struct.center1.xpos+rad,$
    struct.center1.ypos-rad:struct.center1.ypos+rad]

p = icrop[sort(icrop)]
idealthresh = 0.25*max( p[0:.99*(n_elements(p)-1)] )

imask = icrop lt idealthresh
; dim50 = .5*crop
dim50 = wholeimage[struct.center2.xpos-rad:struct.center2.xpos+rad,$
    struct.center2.ypos-rad:struct.center2.ypos+rad]
; dim25 = .25*crop
dim25 = wholeimage[struct.center3.xpos-rad:struct.center3.xpos+rad,$
    struct.center3.ypos-rad:struct.center3.ypos+rad]

; Actually using the wholeimage cropped areas reveal little difference than with the cheating method
; Doesn't really matter which one we use, practically same result


; thresh was -80, now, how do I do quantify magic?
thresh = 0.5*min((SHIFT_DIFF(EMBOSS(crop),dir=3)))

s = SIZE(crop,/dim)
nrow = s[0]
ncol = s[1]

xpb = (SHIFT_DIFF(EMBOSS(crop),dir=3)) lt thresh
ypb = (SHIFT_DIFF(EMBOSS(crop, az=90),dir=1)) lt thresh

display,byte(crop),/square,title='100%'
plot_edges,xpb,thick=6,setcolor=80
plot_edges,ypb,thick=6,setcolor=255
; -80 is about 3 stddev() above the minimum
; -80 is also about half the minimum of xpb/ypb

xpb = (SHIFT_DIFF(EMBOSS(dim50),dir=3)) lt thresh/2
ypb = (SHIFT_DIFF(EMBOSS(dim50, az=90),dir=1)) lt thresh/2

; ps_start,filename='plots_tables_images/dim50.eps',/color,/encapsulated,xsize=8,ysize=8,/inches
display,byte(dim50),/square,title='50% Dim'
plot_edges,xpb,thick=6,setcolor=80
plot_edges,ypb,thick=6,setcolor=255
; ps_end,resize=100

xpb = (SHIFT_DIFF(EMBOSS(dim25),dir=3)) lt thresh/4
ypb = (SHIFT_DIFF(EMBOSS(dim25, az=90),dir=1)) lt thresh/4
; ps_start,filename='plots_tables_images/dim25.eps',/color,/encapsulated,xsize=8,ysize=8,/inches       
display,byte(dim25),/square,title='25% Dim'
plot_edges,xpb,thick=6,setcolor=80
plot_edges,ypb,thick=6,setcolor=255
; ps_end,resize=100


; ; Working with image of blank sun with real fiducials:
; whitecrop = bytarr(s) + 198  ;198 is the mode of the not-fiducial-maskt
; fakesun = imask*crop + whitecrop*(icrop gt idealthresh)
; ; cgsurface,(SHIFT_DIFF(EMBOSS(fakesun),dir=3))
; a = SHIFT_DIFF(EMBOSS(fakesun),dir=3)
; cgimage,a,/k
; cgimage,a*(a gt 10),/k








; ******************************************************************************************
; ******************************************************************************************
; ******************************************************************************************

wn_row = (size(wholeimage,/dim))[0]
wn_col = (size(wholeimage,/dim))[1]
datmask = bytarr(wn_row,wn_col) + 1
datmask[0.1*wn_row:0.9*wn_row,0.1*wn_col:0.9*wn_col] = 0


; min_val should be a really low number, the mode of wholeimage is 3
min_val = mode(wholeimage)
if total(datmask*wholeimage) gt n_elements(datmask[where(datmask eq 1)])*min_val then begin
   ; Don't use this image, bro.
endif

; If in the case where we want the above picture still... then....

stop

; Dickin' around with convol()
kernel = [[-1,1,-1],[1,1,1],[-1,1,-1]]
cgimage,convol(crop,kernel),output='kerneltest.png',/k

stop

; Testing out with diagonals
wholeimage = BYTSCL( READ_TIFF('plots_tables_images/diag.tiff',channels=1) )
crop = wholeimage[struct.center1.xpos-rad:struct.center1.xpos+rad,$
    struct.center1.ypos-rad:struct.center1.ypos+rad]
cgimage,emboss(crop,az=45),/k



; Big ass kernel is not good
kernel = [[1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,1],$
        [-1,1,-1,-1,-1,-1,-1,-1,-1,-1,1,-1],$
        [-1,-1,1,-1,-1,-1,-1,-1,-1,1,-1,-1],$
        [-1,-1,-1,1,-1,-1,-1,-1,1,-1,-1,-1],$
        [-1,-1,-1,-1,1,-1,-1,1,-1,-1,-1,-1],$
        [-1,-1,-1,-1,-1,1,1,-1,-1,-1,-1,-1],$
        [-1,-1,-1,-1,-1,1,1,-1,-1,-1,-1,-1],$
        [-1,-1,-1,-1,1,-1,-1,1,-1,-1,-1,-1],$
        [-1,-1,-1,1,-1,-1,-1,-1,1,-1,-1,-1],$
        [-1,-1,1,-1,-1,-1,-1,-1,-1,1,-1,-1],$
        [-1,1,-1,-1,-1,-1,-1,-1,-1,-1,1,-1],$
        [1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,1]]
; ******************************************************************************************
; ******************************************************************************************
; ******************************************************************************************

stop
; The sunthetic image has too-nice edges that they end up being edge-detected 
; So I actually didn't anticipate this.

; window,0
; !p.multi=[0,2,1]
; cgimage,xpb*crop,/k
; cgimage,ypb*crop,/k
; !p.multi=0

ind_col = WHERE(xpb eq 1) mod ncol
ind_row = WHERE(ypb eq 1)/nrow


a = MODE(ind_col)
b = MODE(ind_col[WHERE(ind_col ne a)])

c = MODE(ind_row)
d = MODE(ind_row[WHERE(ind_row ne f)])



; Just to make it sorted
xpos = [a,b]
ypos = [c,d]
xpos = xpos[SORT(xpos)]
ypos = ypos[SORT(ypos)]

; Because fiducials are 2 pixels wide 
xmask = [xpos[0]-1,xpos[0],xpos[1]-1,xpos[1]]
ymask = [ypos[0]-1,ypos[0],ypos[1]-1,ypos[1]]

finish = SYSTIME(1,/s)
IF KEYWORD_SET(time) THEN print, 'merrygotrace took: '+strcompress(finish-start)+$
    ' seconds'

end