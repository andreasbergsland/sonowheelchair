<CsoundSynthesizer>
<CsOptions>
-odac1  -b128 -B256
</CsOptions>
<CsInstruments>
sr		=		48000
ksmps		=		1
nchnls	=		2

giOSCh1	OSCinit	8035
giOSCh2	OSCinit	8034
giOSCh3	OSCinit	8036

instr		1
kTime		timeinsts
ain, adum	ins
k1, k2, k3, k4, k5, k6, k7, k8, k9, k10		init		0
k11, k12, k13, k14, k15, k16, k17, k18, k19, k20		init		0
k21, k22, k23, k24, k25, k26, k27, k28, k29, k30		init		0
;k31, k32, k33, k34, k35, k36, k37, k38, k39, k30		init		0
aVal 		init		0
;kans		OSClisten	giOSCh1, "/sensors", "ffffffffff", k1, k2, k3, k4, k5, k6, k7, k8, k9, k10
kans		OSClisten	giOSCh1, "/euler", "fff", k1, k2, k3
kans		OSClisten	giOSCh1, "/linear", "fff", k4, k5, k6
kans		OSClisten	giOSCh2, "/euler", "fff", k7, k8, k9
kans		OSClisten	giOSCh2, "/linear", "fff", k10, k11, k12
kans		OSClisten	giOSCh3, "/euler", "fff", k13, k14, k15
;kans		OSClisten	giOSCh3, "/linear", "fff", k16, k17, k18
;kans		OSClisten	giOSCh2, "/sensors", "ffffffffff", k21, k22, k23, k24, k25, k26, k27, k28, k29, k20
;kans		OSClisten	giOSCh2, "/euler", "fff", k21, k22, k23
;kans		OSClisten	giOSCh3, "/sensors", "ffffffffff", k31, k32, k33, k34, k35, k36, k37, k38, k39, k30
;kans		OSClisten	giOSCh3, "/euler", "fff", k31, k32, k33
; Use accel z
;if		k3+k23+k33 > abs(0.8)	then
kmagnitude	=		sqrt(k4^2+k5^2+k6^2)

k_mms2	= 	kmagnitude * 9806.65
;printk2 	k_mms2
kmag_eul	=		sqrt(k1^2+k2^2+k3^2)

kLastTime	init		0
;foutk	"NoiseTestNGIMU.txt", 6, k_mms2
if kans == 1 then
;dumpk3  k1, k2, k3, "/Users/andber/Desktop/VIBRA/WheelChair/Elen_Snurr2_euler_V.txt", 8, 0
;dumpk3  k4, k5, k6, "/Users/andber/Desktop/VIBRA/WheelChair/Elen_Snurr2_linear_V.txt", 8, 0
;dumpk3  k7, k8, k9, "/Users/andber/Desktop/VIBRA/WheelChair/Elen_Snurr2_euler_B.txt", 8, 0
;dumpk3  k10, k11, k12, "/Users/andber/Desktop/VIBRA/WheelChair/Elen_Snurr2_linear_B.txt", 8, 0
;dumpk3  k13, k14, k15, "/Users/andber/Desktop/VIBRA/WheelChair/Elen_Snurr2_euler_H.txt", 8, 0
;dumpk3  k16, k17, k18, "/Users/andber/Desktop/VIBRA/WheelChair/Elen_Snurr2_linear_H.txt", 8, 0
;kTimeGap	=		kTime - kLastTime
;dumpk2		kTimeGap, kTime, "/Users/andber/Desktop/VIBRA/WheelChair/DeltaTime.txt", 8, 0
;printk2	kTimeGap
;kLastTime	=		kTime
endif
;kDiff2		=		diff(k23) * 100
;kDiff3		=		diff(k33) * 100
;kInSnd	downsamp	ain
;printk	1/kr,	k33
;printk	1/kr,	kInSnd, 50
;endif
;fout		"LatencyTestNGIMUx3.wav", 2, ain, a(kdiff * 1000)
endin
</CsInstruments>
<CsScore>
i1	0	8
</CsScore>
</CsoundSynthesizer>