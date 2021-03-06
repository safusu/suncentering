; docformat = 'rst'
PRO alpha
;+
;   :Description:
;      Finds the center of N whole suns and M partial suns using limb-fitting for the whole suns and simple centroiding for the partial suns
;
;   :Params:
;
;   :TODO: 
;       NONE, BRAH
;
; idldoc,root='/Users/jerensuzuki/Documents/suncentering', output='rbdoc',format_style='rst',/user,/quiet,markup_style='rst'
;-
COMPILE_OPT idl2
ON_ERROR,1

; Centers of dottedimage.fits
; wholeimage[200,300] = 255
; wholeimage[202,139] = 255
; wholeimage[87,231] = 255
; wholeimage[401,45] = 255
; wholeimage[23,143] = 255
; wholeimage[34,290] = 255
; wholeimage[420,242] = 255

; Main sun x pos:       210.50238
; Main sun y pos:       154.27054
; 50% sun x pos:        337.80600
; 50% sun y pos:        76.894958
; 25% sun x pos:        78.683426
; 25% sun y pos:        235.11536

; Our list of images to take centers of
wholeimage = mrdfits('../fits_files/dottedimage.fits',/sil)
w1_w2_p3 = mrdfits('../fits_files/partial3rd.fits',/sil)
w1_p2_p3 = mrdfits('../fits_files/2partials.fits',/sil)
reg12 = mrdfits('../fits_files/1_2.fits',/sil)
reg13 = mrdfits('../fits_files/1_3.fits',/sil)
reg23 = mrdfits('../fits_files/2_3.fits',/sil)
w2_p3 = mrdfits('../fits_files/w2_p3.fits',/sil)
p1_w2_w3 = mrdfits('../fits_files/p1_w2_w3.fits',/sil)
p1_w2_p3 = mrdfits('../fits_files/p1_w2_p3.fits',/sil)
p1_p2_w3 = mrdfits('../fits_files/p1_p2_w3.fits',/sil)
w1_p2_w3 = mrdfits('../fits_files/w1_p2_w3.fits',/sil)
p1_w3 = mrdfits('../fits_files/p1_w3.fits',/sil)
p1_w2 = mrdfits('../fits_files/p1_w2.fits',/sil)
w1_p3 = mrdfits('../fits_files/w1_p3.fits',/sil)
albsun = mrdfits('../fits_files/albsun.fits',/sil)
corner = mrdfits('../fits_files/corner.fits',/sil)
corner2 = mrdfits('../fits_files/corner2.fits',/sil)
corner3 = mrdfits('../fits_files/corner3.fits',/sil)
somesun = mrdfits('sun2.fits',/sil)
tritest = mrdfits('tritest.fits',/sil)

; Take your pick of which to center

startimage=wholeimage
; startimage=w1_w2_p3
; startimage=w1_p2_p3
; startimage=reg12
; startimage=reg23
; startimage=reg13
; startimage=w2_p3
; startimage=p1_w2_w3
; startimage=p1_w2_p3
; startimage=p1_p2_w3
; startimage=w1_p2_w3
; startimage=p1_w3
; startimage=p1_w2
; startimage=w1_p3
; startimage = albsun
; startimage = somesun
; startimage = tritest

; alright gay shit, if I'm using tritest I have to use different parameters
; !param.disk_brightness -> 110
; !param.onedsumthresh -> 150
; secondary smoothing parameter -> 15
; a = partialcenter(corner)

; how to set params based on startimage?
; profiler
; profiler,/system

; takes ~.15 s to run albert's image


tic
; defparams, 'pblock_alb3sun.txt'
; defparams, 'pblock_albdimsun.txt'
defparams, 'pblock_orig_small.txt'
toc
; .0004 to here
defsysvarthresh, startimage
toc
; .037 to here
grannysmith = everysun(startimage)
toc
; .085 to here
fuji = picksun(startimage, grannysmith)
toc
; .138 to here
limbfittedcentroids=centroidwholesuns(fuji,startimage)
toc
; .140 to here
bbb = para_fid(startimage,limbfittedcentroids)
; .146 to here
toc
tmpimage = startimage

if n_elements(limbfittedcentroids) gt 1 then begin
    for i =0,n_elements(limbfittedcentroids)-1 do begin
        tmpimage[limbfittedcentroids[i].limbxpos:limbfittedcentroids[i].limbxpos,*] = 255
        tmpimage[*,limbfittedcentroids[i].limbypos:limbfittedcentroids[i].limbypos] = 255
    endfor
endif else begin
    tmpimage[limbfittedcentroids[0].limbxpos:limbfittedcentroids[0].limbxpos,*] = 255
    tmpimage[*,limbfittedcentroids[0].limbypos:limbfittedcentroids[0].limbypos] = 255
endelse

; so the rough center is a bit off. Gasp!

; profiler,/report,data=data
; profiler,/reset,/clear
; print,data[sort(-data.time)],format='(A-20, I7, F12.5, F10.5, I9)'

atmp = startimage

; So I have to highlight fiducials

for i = 0,n_elements(bbb)-1 do begin
    for j = 0,n_elements((*(bbb[i])).fidarr)-1 do begin

        if ((*(bbb[i])).fidarr)[j].subx ne 0 or ((*(bbb[i])).fidarr)[j].suby ne 0 then begin
        atmp[((*(bbb[i])).fidarr)[j].subx + limbfittedcentroids[i].limbxpos - !param.crop_box -1:((*(bbb[i])).fidarr)[j].subx + limbfittedcentroids[i].limbxpos - !param.crop_box+1,((*(bbb[i])).fidarr)[j].suby + limbfittedcentroids[i].limbypos - !param.crop_box-1:((*(bbb[i])).fidarr)[j].suby + limbfittedcentroids[i].limbypos - !param.crop_box+1]=255
        endif
    endfor
endfor

; print,'Main sun x pos:',limbfittedcentroids[0].limbxpos
; print,'Main sun y pos:',limbfittedcentroids[0].limbypos
; print,'50% sun x pos: ',limbfittedcentroids[1].limbxpos
; print,'50% sun y pos: ',limbfittedcentroids[1].limbypos
; print,'25% sun x pos: ',limbfittedcentroids[2].limbxpos
; print,'25% sun y pos: ',limbfittedcentroids[2].limbypos

window,0
cgimage,tmpimage,/k
window,1
cgimage,atmp,/k
stop

end