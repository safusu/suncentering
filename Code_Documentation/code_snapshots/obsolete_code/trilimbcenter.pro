PRO makelimbstrips, thresh, xstrips, ystrips, file, ministrip_length, scan_width, sigmavalue, $
    sundiam, nstrips=nstrips, region=region, time=time
;+
;   :Description:
;       Makes limb strips from full-length strips
;
;   :Params:
;       file: in, required, type=string, default='triplesun.bmp'
;           File to be read in
;       ministrip_length: in, required, type=byte, default=13
;           How long the total array of the cut-down strip will be
;       scan_width: in, required, type=integer, default=5
;           Indicates how far apart to scan
;       sigmavalue: in, required, type=integer, default=2
;           Sets the threshold to be::
;   
;           max(image) - sigmavalue*stddev(image)
;
;       sundiam : in, required, type=byte, default=70
;           Approximate diameter of sun in pixels. (Based on bmp image)
;       thresh : out, required, type=float
;           Threshold used to select pixels
;
;   :Keywords:
;       nstrips : in, optional, type=byte, default=5
;           How many strips to select, centered around the row/col diameter
;       region: in, required, type=integer, default=1
;           Which sun out of the three to find the center of. Defaults to the brightest sun
;       time : in, optional
;           Prints the elapsed time
;
;   :TODO:
;
;   Exactly how much data should be stored in a structure? Since we're interested in saving space,
;   doesn't make sense to repeat any data in the structures.
;-

IF n_elements(file)             EQ 0    THEN file               = 'triplesun.bmp'
IF n_elements(ministrip_length) EQ 0    THEN ministrip_length   = 9
IF n_elements(nstrips)          EQ 0    THEN nstrips            = 5 
IF n_elements(scan_width)       EQ 0    THEN scan_width         = 5 
IF n_elements(sigmavalue)       EQ 0    THEN sigmavale          = 2
IF n_elements(sundiam)          EQ 0    THEN sundiam            = 70
IF n_elements(region)           EQ 0    THEN region             = 1

makestrips, thresh, c4xstrips, c4ystrips, file, scan_width, sigmavalue, sundiam, nstrips=nstrips, $
    region=region, time=time

start = systime(1,/seconds)

ministrip_side_buffer = ministrip_length/2 
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
        STARTPOINTS:bytarr(ministrip_length), $
        ENDPOINTS:bytarr(ministrip_length)},n_elements(c4xstrips))
ystrips = REPLICATE({COLINDEX:0, BEGINDEX:0, ENDINDEX:0, $
        STARTPOINTS:bytarr(ministrip_length), $
        ENDPOINTS:bytarr(ministrip_length)},n_elements(c4ystrips))

;Filling out structure with cut-down strip information
FOR i = 0,n_elements(c4xstrips) - 1 DO BEGIN
    xstrips[i].ROWINDEX     = c4xstrips[i].ROWINDEX
    ; If there is no strip that cuts through the sun, set things to 0
    IF rowchord_endpoints[0,i] EQ -1 THEN BEGIN
        xstrips[i].STARTPOINTS  = fltarr(ministrip_length) 
        xstrips[i].BEGINDEX     = 0
    ENDIF ELSE BEGIN
        ; STARTPOINTS is the cut down strip with length = ministrip_length and contains
        ; the indices from rowchord_endpoints[0,i] +/- ministrip_side_buffer
        xstrips[i].STARTPOINTS  = $
            (c4xstrips[i].ARRAY)[rowchord_endpoints[0,i]-ministrip_side_buffer:$
            rowchord_endpoints[0,i]+ministrip_side_buffer]   
        ; BEGINDEX is the index of the strip where it begins. 
        ; e.g., the array is 5 long, starts from index 9 and is centered around index 11
        xstrips[i].BEGINDEX     = fix(rowchord_endpoints[0,i] - ministrip_side_buffer)
    ENDELSE
    IF rowchord_endpoints[1,i] EQ -1 THEN BEGIN
        xstrips[i].ENDPOINTS    = fltarr(ministrip_length)
        xstrips[i].ENDINDEX    = 0
    ENDIF ELSE BEGIN
        xstrips[i].ENDPOINTS  = $
            (c4xstrips[i].ARRAY)[rowchord_endpoints[1,i]-ministrip_side_buffer:$
            rowchord_endpoints[1,i]+ministrip_side_buffer]   
        xstrips[i].ENDINDEX     = fix(rowchord_endpoints[1,i] - ministrip_side_buffer)
    ENDELSE
ENDFOR

FOR k = 0,n_elements(c4ystrips) - 1 DO BEGIN
    ystrips[k].COLINDEX     = c4ystrips[k].COLINDEX
    IF colchord_endpoints[0,k] EQ -1 THEN BEGIN
        ystrips[k].STARTPOINTS  = fltarr(ministrip_length) 
        ystrips[k].BEGINDEX     = 0
    ENDIF ELSE BEGIN 
        ystrips[k].STARTPOINTS  = (c4ystrips[k].ARRAY)[colchord_endpoints[0,k]- $
            ministrip_side_buffer:colchord_endpoints[0,k]+ministrip_side_buffer]
        ystrips[k].BEGINDEX     = fix(colchord_endpoints[0,k] - ministrip_side_buffer)
    ENDELSE
    IF colchord_endpoints[1,k] EQ -1 THEN BEGIN
        ystrips[k].ENDPOINTS    = fltarr(ministrip_length) 
        ystrips[k].ENDINDEX     = 0        
    ENDIF ELSE BEGIN
        ystrips[k].ENDPOINTS    = (c4ystrips[k].ARRAY)[colchord_endpoints[1,k]- $
        ministrip_side_buffer:colchord_endpoints[1,k]+ministrip_side_buffer]
        ystrips[k].ENDINDEX     = fix(colchord_endpoints[1,k] - ministrip_side_buffer) 
    ENDELSE
ENDFOR

finish = systime(1,/seconds)

IF keyword_set(time) THEN  print,'Elapsed Time for makelimbstrips: ', $
    strcompress(finish-start,/rem),' seconds'
RETURN
END



PRO makestrips, thresh, xstrips, ystrips, file, scan_width, sigmavalue, sundiam, nstrips=nstrips, $
    region=region, time=time
;+
;   :Description:
;       Only saves 5 strips centered around the solar diameter to reduce the amount of limb-
;           darkened pixels and to make the polynomial-fitted limbs more-or-less look similar. 
;
;   :Params:
;   file: in, required, type=string, default='triplesun.bmp'
;       File to be read in
;   scan_width: in, required, type=integer, default=5
;       Indicates how far apart to scan
;   sigmavalue: in, required, type=integer, default=2
;       Sets the threshold to be::
;   
;       max(image) - sigmavalue*stddev(image)
;
;   sundiam : in, required, type=byte, default=70
;       Approximate diameter of sun in pixels. (Based on bmp image)
;   thresh : out, required, type=float
;       Threshold used to select pixels
;   xstrips : out, required, type=structure
;       Structure containing row strips
;   ystrips : out, required, type=structure
;       Structure containing column strips
;
;   :Keywords:
;   nstrips : in, optional, type=byte, default=5
;       How many strips to select, centered around the row/col diameter
;   region : in, required, type=integer, default=1
;       Which sun out of the three to find the center of. Defaults to the brightest sun
;   time : in, optional
;       Prints elapsed time
;-

IF n_elements(file)         EQ 0    THEN file       = 'triplesun.bmp'
IF n_elements(nstrips)      EQ 0    THEN nstrips    = 5
IF n_elements(region)       EQ 0    THEN region     = 1
IF n_elements(scan_width)   EQ 0    THEN scan_width = 5
IF n_elements(sigmavalue)   EQ 0    THEN sigmavalue = 2
IF n_elements(sundiam)      EQ 0    THEN sundiam    = 70

struct = tribox(file, scan_width, sigmavalue, sundiam, region=region, time=time)
; trimask, file, xpos, ypos, scan_width, sigmavalue, sundiam, thresh, region=region, time=time

start = systime(1,/seconds)

cropped_image = struct.image
thresh = max(cropped_image) - stddev(cropped_image)*sigmavalue 

colscan = 0

WHILE total(where(cropped_image[colscan,*] GT thresh/2)) EQ -1 DO BEGIN
    colscan++
ENDWHILE
rowscan = fix(((where(cropped_image[colscan,*] GT thresh/2))[0] - sundiam/2 + $
        n_elements(where(cropped_image[colscan,*] GT thresh/2))/2 ))

rowendscan = rowscan + sundiam
colendscan = colscan + sundiam

xpos = (colscan + colendscan)/2.; + struct.xoffset
ypos = (rowscan + rowendscan)/2.; + struct.yoffset

s = size(cropped_image,/dimensions)
length = s[0]
height = s[1]

rowchord_endpoints = fltarr(2,nstrips)
colchord_endpoints = fltarr(2,nstrips)

xstrips = REPLICATE({ROWINDEX:0,ARRAY:bytarr(length)},nstrips)
ystrips = REPLICATE({COLINDEX:0,ARRAY:bytarr(height)},nstrips)

FOR i = 0,nstrips - 1 DO BEGIN
    xstrips[i].ROWINDEX = i
    xstrips[i].ARRAY = cropped_image[*, round(xpos)+(i-nstrips/2)*scan_width]
ENDFOR

FOR k = 0,nstrips - 1 DO BEGIN
    ystrips[k].COLINDEX = k
    ystrips[k].ARRAY = cropped_image[round(ypos)+(k-nstrips/2)*scan_width,*]
ENDFOR

finish = systime(1,/seconds)
IF keyword_set(time) THEN  print,'Elapsed Time for makestrips: ', $
    strcompress(finish-start,/rem),' seconds'

RETURN
END


PRO limbfit, thresh, xpos, ypos, file, ministrip_length, order, scan_width, sigmavalue, sundiam, $
    nstrips=nstrips, plot=plot, region=region, time=time
;+
;   :Description:
;   Uses the data from makelimbstrips and fits an n-th order polynomial to the limb to find where
;       it crosses the threshold.
;
;   :Params:
;       file : in, required, type=string, default='triplesun.bmp'
;           File to be read in
;       ministrip_length : in, required, default=9
;           How long the trimmed down strip will be
;       order : in, required, type=integer, default=3
;           What order polynomial to use for POLY_FIT()
;       scan_width : in, required, type=integer, default=5
;           Indicates how far apart to scan
;       sigmavalue : in, required, type=integer, default=2
;           Sets the threshold to be::
;
;           max(image) - sigmavalue*stddev(image)
;
;       sundiam : in, required, type=byte, default=70
;           Approximate diameter of sun in pixels. (Based on bmp image)
;       thresh : out, required, type=float
;           Threshold used to select pixels
;       xpos : out, required, type=float
;           X center
;       ypos : out, required, type=float
;           Y center
;
;   :Keywords:
;       nstrips : in, optional, type=byte, default=5
;           How many strips to select, centered around the row/col diameter
;       region : in, required, type=integer, default=1
;           Which sun out of the three to find the center of. Defaults to the brightest sun
;       plot : in, optional
;           Makes some nice plots
;       time : in, optional
;           Prints the elapsed time
;-

; Setting default values
IF n_elements(file)                 EQ 0    THEN file              = 'triplesun.bmp'
IF n_elements(ministrip_length)     EQ 0    THEN ministrip_length  = 9
IF n_elements(nstrips)              EQ 0    THEN nstrips           = 5
IF n_elements(order)                EQ 0    THEN order             = 2
IF n_elements(region)               EQ 0    THEN region            = 1
IF n_elements(scan_width)           EQ 0    THEN scan_width        = 5
IF n_elements(sigmavalue)           EQ 0    THEN sigmavalue        = 2
IF n_elements(sundiam)              EQ 0    THEN sundiam           = 70

; Run the program to get our structures
makelimbstrips, thresh, xstrips, ystrips, file, ministrip_length, scan_width, sigmavalue, sundiam, $
    nstrips=nstrips, region=region, time=time

start = systime(1,/seconds)

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
    ; Using fz_roots instead of spline interpolating. Saving lines and making code more readable
    startresult     = reform(poly_fit(xarr,xstrips[n].STARTPOINTS,order))
    endresult       = reform(poly_fit(xarr,xstrips[n].ENDPOINTS,order))

    ; Solving for roots but want to include threshold value
    startresult[0]  -=thresh
    endresult[0]    -=thresh

    IF xstrips[n].BEGINDEX GT 0 THEN BEGIN
        ; Get roots (complex)
        begroots    = fz_roots(startresult)
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
xpos = mean(xlenarr[where(xlenarr ne 0)])
ypos = mean(ylenarr[where(ylenarr ne 0)])

struct = tribox(file, scan_width, sigmavalue, sundiam, region=region, time=time)
xpos+=struct.xoffset
ypos+=struct.yoffset

IF keyword_set(plot) THEN BEGIN
    wn = 3
    startresult = poly_fit(xarr,xstrips[wn].STARTPOINTS,order)
    endresult = poly_fit(xarr,xstrips[wn].ENDPOINTS,order)

    CASE order OF
    1: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr,tx)
        END
    2: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2,tx)
        END
    3: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3,tx)
        END
    4: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4,tx)
        END
    5: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5,tx)
        END    
    6: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5 + $
                startresult[6]*xarr^6,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5 + $
                endresult[6]*xarr^6,tx)
        END
    7: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5 + $
                startresult[6]*xarr^6 + startresult[7]*xarr^7,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
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
    legend,['Actual Data Values','Splined Data'],linestyle=[0,1],/bottom,/right,charsize=2
    ; device,/close
    ; set_plot,'x'
    window,0
    ; set_plot,'ps'
    ; device,filename=file+'part2'+'.ps',/encapsulated
    plot,xarr+xstrips[wn].ENDINDEX,xstrips[wn].ENDPOINTS,xs=3,ys=3,title='Limb Profile',$
        xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    oplot,tx+xstrips[wn].ENDINDEX,atmp,linestyle=1
    hline,thresh,linestyle=2
    legend,['Actual Data Values','Splined Data'],linestyle=[0,1],/bottom,/left,charsize=2
    ; device,/close
    ; set_plot,'x'

    wn = 3
    startresult = poly_fit(xarr,xstrips[wn].STARTPOINTS,order)
    endresult = poly_fit(xarr,xstrips[wn].ENDPOINTS,order)

    CASE order OF
    1: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr,tx)
        END
    2: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2,tx)
        END
    3: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3,tx)
        END
    4: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4,tx)
        END
    5: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5,tx)
        END    
    6: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5 + $
                startresult[6]*xarr^6,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5 + $
                endresult[6]*xarr^6,tx)
        END
    7: BEGIN
        xtmp = spline(xarr,startresult[0] + startresult[1]*xarr + startresult[2]*xarr^2 + $
                startresult[3]*xarr^3 + startresult[4]*xarr^4 + startresult[5]*xarr^5 + $
                startresult[6]*xarr^6 + startresult[7]*xarr^7,tx)
        atmp = spline(xarr,endresult[0] + endresult[1]*xarr + endresult[2]*xarr^2 + $
                endresult[3]*xarr^3 + endresult[4]*xarr^4 + endresult[5]*xarr^5 + $
                endresult[6]*xarr^6 + endresult[7]*xarr^7,tx)
        END
    ENDCASE

    ; A pretty plot for Nicole
    window,3
    ; set_plot,'ps'
    ; device,filename=file+'part1'+'.ps',/encapsulated
    plot,xarr+xstrips[wn].BEGINDEX,xstrips[wn].startpoints,xs=3,ys=3,title='Limb Profile',$
        xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    oplot,tx+xstrips[wn].BEGINDEX,xtmp,linestyle=1
    hline,thresh,linestyle=2
    legend,['Actual Data Values','Splined Data'],linestyle=[0,1],/bottom,/right,charsize=2
    ; device,/close
    ; set_plot,'x'
    window,1
    ; set_plot,'ps'
    ; device,filename=file+'part2'+'.ps',/encapsulated
    plot,xarr+xstrips[wn].ENDINDEX,xstrips[wn].ENDPOINTS,xs=3,ys=3,title='Limb Profile',$
        xtitle='Pixel indices of total strip',ytitle='Brightness',psym=-2;,yr=[0,1.1*max(xtmp)]
    oplot,tx+xstrips[wn].ENDINDEX,atmp,linestyle=1
    hline,thresh,linestyle=2
    legend,['Actual Data Values','Splined Data'],linestyle=[0,1],/bottom,/left,charsize=2
    ; device,/close
    ; set_plot,'x'    
ENDIF

finish = systime(1,/seconds)

IF keyword_set(time) THEN  print,'Elapsed Time for limbfit: ',strcompress(finish-start,/rem),' seconds'
; save,xpos,ypos,thresh,sigmavalue,order,file, ministrip_length,scan_width,$
;     filename='comp6results.sav',/compress

; strformatcode = 'a'+strcompress(strlen(file),/rem)

; OPENW,1,'comp6results.dat' 
; PRINTF,1,xpos,ypos,thresh,sigmavalue,order,ministrip_length,scan_width,file, $
;     format='(F7.2,1X,F7.2,1X,F7.2,I,1X,I,1X,I,1X,I,1X,'+strformatcode+')'
; CLOSE,1

; strformatcode = 'a'+strcompress(strlen(file),/rem)
; OPENW,2,'comp6results.txt' 
; PRINTF,2,xpos,ypos,thresh,sigmavalue,order,ministrip_length,scan_width,file, $
;     format='(F7.2,1X,F7.2,1X,F7.2,I,1X,I,1X,I,1X,I,1X,'+strformatcode+')'
; CLOSE,2
RETURN
END



PRO getstruct, file, struct, scan_width, sigmavalue, sundiam, time=time
;+
;   :Description:
;       Finds the centers of a triple-sun image and loads all relevant information
;       including offsets and angles into a new structure.
;
;   :Params:
;       file: in, required, type = string, default = 'triplesun.bmp'
;           What file to find 3 centers for
;       struct : out, required, type=structure
;           Structure containing the centers and cropped images of all 3 suns
;       scan_width : in, required, type=integer, default=5
;           How apart the scans are for minicrop(). 
;       sigmavalue : in, required, type = integer, default = 2
;          Sets the threshold to be::
;
;           max(image) - sigmavalue*stddev(image)
;
;       sundiam : in, required, type=byte, default=70
;           Approximate diameter of sun in pixels. (Based on bmp image)
;
;   :Keywords:
;       time: in, optional
;           Outputs how much time the program takes
;-
COMPILE_OPT idl2 
on_error,2

start = systime(1,/s)

center1 = {center1,xpos:0d,ypos:0d,thresh:0d}
center2 = {center2,xpos:0d,ypos:0d,thresh:0d}
center3 = {center3,xpos:0d,ypos:0d,thresh:0d}

nstrips=5

; trimask, file, xpos, ypos, scan_width, sigmavalue, sundiam, thresh, region=1, time=time
limbfit, thresh, xpos, ypos, file, ministrip_length, order, scan_width, sigmavalue, sundiam, $
    nstrips=nstrips, plot=plot, region=1, time=time
; struct = tribox(file, scan_width, sigmavalue, sundiam, region=1, time=time)
; xpos+=struct.xoffset
; ypos+=struct.yoffset
center1.xpos = xpos
center1.ypos = ypos
center1.thresh = thresh
;trimask, file, xpos, ypos, scan_width, sigmavalue, sundiam, thresh, region=2, time=time
limbfit, thresh, xpos, ypos, file, ministrip_length, order, scan_width, sigmavalue, sundiam, $
    nstrips=nstrips, plot=plot, region=2, time=time
; struct = tribox(file, scan_width, sigmavalue, sundiam, region=2, time=time)
; xpos+=struct.xoffset
; ypos+=struct.yoffset
center2.xpos = xpos
center2.ypos = ypos
center2.thresh = thresh
;trimask, file, xpos, ypos, scan_width, sigmavalue, sundiam, thresh, region=3, time=time
limbfit, thresh, xpos, ypos, file, ministrip_length, order, scan_width, sigmavalue, sundiam, $
    nstrips=nstrips, plot=plot, region=3, time=time
; struct = tribox(file, scan_width, sigmavalue, sundiam, region=3, time=time)
; xpos+=struct.xoffset
; ypos+=struct.yoffset
center3.xpos = xpos
center3.ypos = ypos
center3.thresh = thresh

theta = !radeg*atan((center3.ypos - center2.ypos)/(center3.xpos - center2.xpos))
hypot = sqrt((center3.ypos - center2.ypos)^2 + (center3.xpos - center2.xpos)^2)
offset = ((center1.xpos - center2.xpos)*(center3.ypos - center2.ypos) - $
    (center1.ypos - center2.ypos)*(center3.xpos - center2.xpos))/hypot

struct = {KAHUNA, center1:center1, center2:center2, center3:center3, $
    theta:theta, offset:offset}
finish = systime(1,/s)
IF keyword_set(time) THEN print, 'getstruct took: '+strcompress(finish-start)+$
    ' seconds'
RETURN
END


FUNCTION cropit, inputarr, location, scan_width, sigmavalue, sundiam, region=region, time=time
;+
;   :Description: 
;       Loads a triple-sun image and crops out selected regions one-by-one.
;
;   :Params:
;       inputarr : in, required, type=byte
;           Starting image to crop
;       location : out, required, type=structure
;           Structure containing the cropped image along with the X and Y distances from origin
;       scan_width : in, required, type=integer, default=5
;           How apart the scans are for minicrop(). 
;       sigmavalue : in, required, type = integer, default = 2
;          Sets the threshold to be::
;
;           max(image) - sigmavalue*stddev(image)
;
;       sundiam: in, required, default=70
;           Approximate diameter of sun in pixels. (Based on bmp image)
;
;   :Keywords:
;       region: in, required, type=integer, default=1
;           Which sun out of the three to find the center of. Defaults to the brightest sun
;       time : in, optional
;         Print the elapsed time
;
;   :Examples:
;       cropped = cropit(inputarr,scan_width,sigmavalue,sundiam,region=1)
;
;-
COMPILE_OPT idl2 
on_error,2

IF n_elements(scan_width) EQ 0 THEN scan_width = 5
IF n_elements(sigmavalue) EQ 0 THEN sigmavalue = 2
IF n_elements(sundiam)    EQ 0 THEN sundiam = 70
IF n_elements(region)     EQ 0 THEN region = 1

start = systime(1,/s)

thresh = max(inputarr) - sigmavalue*stddev(inputarr)
temparr = inputarr * (inputarr gt thresh)

minicrop, temparr, rowscan, colscan, rowendscan, colendscan, scan_width, sundiam, thresh,time=time


;***************************************************************************************************
;                                                                                                  *
;                                                                                                  *
;                                                                                                  *
; Making a big fuss over sort(), let's figure out how it can reduce/remove the multiple scanning   *
;                                                                                                  *
;                                                                                                  *
;                                                                                                  *
;                                                                                                  *
;***************************************************************************************************


; a=inputarr
; b = where(a gt thresh, n_gt,complement=leftout)
; c = array_indices(a,b)
; ; These are x and y positions where a gt thresh
; d = array_indices(a,leftout)
; ; These are the x and y positions of everywhere else


; stop
CASE region OF

1: BEGIN
    cropped=inputarr[colscan*scan_width:colendscan*scan_width,rowscan*scan_width:$
        rowendscan*scan_width]
    END

2: BEGIN
    inputarr[colscan*scan_width:colendscan*scan_width,rowscan*scan_width:rowendscan*scan_width] = 0
    
    ;****************************************************************************************

    temparr = inputarr * (inputarr lt thresh)

    minicrop,temparr, rowscan, colscan, rowendscan, colendscan, scan_width,$
        sundiam, thresh,time=time

    cropped=inputarr[colscan*scan_width:colendscan*scan_width,rowscan*scan_width:$
        rowendscan*scan_width]
    END

3: BEGIN
    inputarr[colscan*scan_width:colendscan*scan_width,rowscan*scan_width:rowendscan*scan_width] = 0

    ;****************************************************************************************

    ; Step 2: Black out the first dimsum
    temparr = inputarr * (inputarr lt thresh)

    minicrop,temparr, rowscan, colscan, rowendscan, colendscan, scan_width,$
        sundiam, thresh,time=time

    inputarr[colscan*scan_width:colendscan*scan_width,rowscan*scan_width:rowendscan*scan_width] = 0

    ;****************************************************************************************

    ; Step 3: Crop what's left
    temparr = inputarr * (inputarr lt thresh)

    minicrop,temparr, rowscan, colscan, rowendscan, colendscan, scan_width,$
        sundiam, thresh,time=time

    cropped=inputarr[colscan*scan_width:colendscan*scan_width,rowscan*scan_width:$
        rowendscan*scan_width]

    END
ENDCASE
; window,region
; cgimage,cropped,/k
location = {image:cropped,xoffset:colscan*scan_width,yoffset:rowscan*scan_width}
finish = systime(1,/s)
IF keyword_set(time) THEN print,' cropit() took '+strcompress(finish-start,/remove)+' seconds'
RETURN,location
END




PRO minicrop, temparr, rowscan, colscan, rowendscan, colendscan, scan_width,$
        sundiam, thresh,time=time
;+
;   :Description: 
;       Small function to keep code small in cropit. Finds the row where the threshold is crossed
;       and then steps back in the x-direction to find the left side of the cropping box. Skips 
;       over the sun by a predetermined value then crops out the sun. 
;
;   :Params:
;       temparr : in, required, type=byte
;           2D array to check boundary limits of
;       rowscan : out, required, type=integer
;           Where to crop the rows from
;       colscan : out, required, type=integer
;           Where to crop the columns from
;       rowendscan : out, required, type=integer
;           Where to crop the rows to
;       colendscan : out, required, type=integer
;           Where to crop the columns to
;       scan_width : in, required, type=integer, default=5
;           How apart the scans are for minicrop(). 
;       sundiam : in, required, type=byte, default=70
;           Approximate diameter of sun in pixels. (Based on bmp image)
;       temparr : in, required, type=byte
;           2D array to check boundary limits of
;       thresh : in, required, type=float
;           What the minimum threshold will be for scanning
;
;   :Keywords:
;       time : in, optional
;           Print the elapsed time
;-
COMPILE_OPT idl2 
on_error,2

start = systime(1,/s)

;rowscan=0
;WHILE total(where(temparr[*,rowscan*scan_width] GT thresh/2)) EQ -1 DO BEGIN
;    rowscan++
;ENDWHILE
;; Doing it this way so that if in the case of 3 suns, if 1 sun is more left than the sun which 
;; is the most bottom, the cropping will correctly choose the right sun.
;colscan = fix(((where(temparr[*,rowscan*scan_width] GT thresh/2))[0] - sundiam/2 + $
;        n_elements(where(temparr[*,rowscan*scan_width] GT thresh/2))/2 )/scan_width)
;

; Redoing it so that we scan left to right before bottom to top

colscan = 0
WHILE total(where(temparr[colscan*scan_width,*] GT thresh/2)) EQ -1 DO BEGIN
    colscan++
ENDWHILE
rowscan = fix(((where(temparr[colscan*scan_width,*] GT thresh/2))[0] - sundiam/2 + $
        n_elements(where(temparr[colscan*scan_width,*] GT thresh/2))/2 )/scan_width)




rowendscan = rowscan + sundiam/scan_width ; Jumping to other side of sun
colendscan = colscan + sundiam/scan_width

;Since the column scanning is rough, have to give the ends a little room.
rowscan     -= 3
colscan     -= 3
rowendscan  += 3
colendscan  += 3

finish = systime(1,/s)
IF keyword_set(time) THEN print,' minicrop took '+strcompress(finish-start,/remove)+' seconds'

RETURN
END



; docformat = 'rst'
;
;+
; NAME: 
;   TRICENTER
;
; PURPOSE:
;   Finds the center of 3 suns in a single image. Currently limited to a .bmp test image. 
;
; :Author:
;   JEREN SUZUKI::
;
;       Space Sciences Laboratory
;       7 Gauss Way
;       Berkeley, CA 94720 USA
;       E-mail: jsuzuki@ssl.berkeley.edu
;-

; PRO trilimbcenter, file, scan_width, sigmavalue, sundiam, time=time
;+
;   :Description:
;       This version uses limb fitting opposed to masking (tricenter). 
;
;   :Params:
;       file: in, required, type = string, default = 'triplesun.bmp'
;           What file to find 3 centers for
;       scan_width: in, required, type = integer, default = 5
;           How apart the scans are for minicrop(). Overrides defaults in crop().
;       sigmavalue: in, required, type = integer, default = 2
;          Sets the threshold to be::
;
;           max(image) - sigmavalue*stddev(image)
;
;       sundiam : in, required, type=byte, default=70
;           Approximate diameter of sun in pixels. (Based on bmp image)
;
;   :Keywords:
;       time: in, optional
;           Outputs how much time the program takes
;
;   :TODO: 
;       Make it use limb-fitting instead of simple masking
;   
;       Can't use .run tricenter anymore since it's broken up. resolve_all won't solve it
;-
COMPILE_OPT idl2 
on_error,2

IF n_elements(file)         EQ 0 THEN   file = 'yetanothertriplesun.bmp'
IF n_elements(scan_width)   EQ 0 THEN   scan_width = 5
IF n_elements(sigmavalue)   EQ 0 THEN   sigmavalue = 2
IF n_elements(sundiam)      EQ 0 THEN   sundiam = 70

start=systime(1,/s)

getstruct, file, struct, scan_width, sigmavalue, sundiam, time=time

tmpimage = read_bmp(file) 
s = size(tmpimage,/dimensions)
n_col = s[1]
n_row = s[2]
image = reform(tmpimage[0,*,*])
image2 = image
image3 = image

image[struct.center1.xpos,*]=20
image[*,struct.center1.ypos]=20
image2[struct.center2.xpos,*]=20
image2[*,struct.center2.ypos]=20
image3[struct.center3.xpos,*]=20
image3[*,struct.center3.ypos]=20

; window,0
; cgimage,image,/k
; window,2
; cgimage,image2,/k
; window,3
; cgimage,image3,/k

finish = systime(1,/s)
IF keyword_set(time) THEN print, 'tricenter took: '+strcompress(finish-start)+$
    ' seconds'
stop
END

