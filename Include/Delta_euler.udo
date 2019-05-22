; Delta_euler
; udo that gives the delta (differentiatiation/rate of change) for an euler array (xyz) input
; and compensates for jumps between -180 and 180 for the euler values (phase unwrapping)
; kOut[]	Delta_euler		kArr[], kdeltime, imaxdel
opcode	Delta_euler, k[], k[]kio
kArr[], kdeltime, imaxdel, icnt		xin
kDel[]	init		lenarray(kArr)
if icnt >= lenarray(kArr)-1 goto body
kArr[] Delta_array kArr, kdeltime, imaxdel, icnt+1
body:	
kDel[icnt]		vdel_k		kArr[icnt], kdeltime, imaxdel	; Delay
if	(kArr[icnt] - kDel[icnt]) > 300	then
kArr[icnt]		=			(kArr[icnt] - kDel[icnt] - 360)
elseif (kArr[icnt] - kDel[icnt]) < -300	then
kArr[icnt]		=			(kArr[icnt] - kDel[icnt] + 360)
else
kArr[icnt]		=			(kArr[icnt] - kDel[icnt])
endif
xout	kArr
endop