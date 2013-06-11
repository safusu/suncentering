FUNCTION setbetterpeak, input, nsuns
;+
;   :Description:
;       Returns peaks of 2nd deriv of sorted array to set thresholds for image
;
;   :Params:
;       input: in, required
;           Starting input image
;
;       nsuns: in, required
;           Number of suns
;
;-

; instead of sorting the entire image, let's try getting away with sorting a whole lot less

trimmed = input[where(input gt 1)]
peakarr = FLTARR(nsuns)
beensorted = SORT(trimmed)
sorted = trimmed[beensorted]
sorted = sorted[0:(1-!param.elim_perc/1000)*(N_ELEMENTS(sorted)-1)]
; .03 to run to here
 ; Now takes .0075

a = DERIV(SMOOTH(FLOAT(sorted), !param.n_smooth, /edge_truncate))
arr = DERIV(SMOOTH(a, !param.n_smooth, /edge_truncate))
; .05 to run to here
; Now takes .0075

; Eliminate the peak on the right end of the array
arr = arr[0:-10000]

if nsuns gt 1 then begin
    for i = 0,nsuns-1 do begin
        peakarr[i] = MEAN(WHERE(arr eq MAX(arr)))
        ; so that the next peak is the real peak
        arr=[arr,fltarr(13000)]
        arr[peakarr[i]-13000:peakarr[i]+13000]=0
        arr=arr[0:-13000]
    endfor
endif else begin
    peakarr = MEAN(WHERE(a[0:-10000] eq MAX(a[0:-10000])))
endelse
; .06 to run to here
; Now .008

RETURN,{peakarr:peakarr,sorted:sorted}
end