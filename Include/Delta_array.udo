; Delta_array
; udo that gives the delta (differentiatiation/rate of change) for an array input
; kOut[]	Delta_array	kArr[], kdeltime, imaxdel
opcode	Delta_array, k[], k[]kio
kArr[], kdeltime, imaxdel, icnt		xin
kDel[]	init		lenarray(kArr)
if icnt >= lenarray(kArr)-1 goto body
kArr[] Delta_array kArr, kdeltime, imaxdel, icnt+1
body:	
kDel[icnt]		vdel_k		kArr[icnt], kdeltime, imaxdel	; Delay
kArr[icnt]		=			kArr[icnt] - kDel[icnt]
xout	kArr
endop