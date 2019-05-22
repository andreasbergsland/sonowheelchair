<CsoundSynthesizer>
<CsOptions>
-odac0  -b128 -B256   
; Set your path here
--omacro:Path=/Users/andber/Desktop/VIBRA/WheelChair/
</CsOptions>
<CsInstruments>
sr		=		48000
ksmps		=		1
nchnls	=		2

; UDOs
#include	"include/Delta_array.udo"

#include	"include/Delta_euler.udo"

; Receive OSC from sensors
giOSCh34	OSCinit	8000		; Change this back to 8034
giOSCh35	OSCinit	8035
giOSCh36	OSCinit	8036
giOSC_Max	OSCinit	2000

alwayson	"receiveOSC"

;**********************************************************************
;		Instrument for receiving OSC from Max and NGIMUs
;**********************************************************************

		instr		receiveOSC
; Set path in options
SPath		strcpy	"$Path"

gktime		timeinsts
itim     	date
SDate     	dates     	itim

; Receive OSC from Max
S_ID		strcpy	""
SColor	strcpy	""
kDur		init		0

kIDChg	OSClisten	giOSC_Max, "/ID", "s", S_ID
kColorChg	OSClisten	giOSC_Max, "/color", "s", SColor
kDur		OSClisten	giOSC_Max, "/dur", "i", kDur
printf	"ID = %s, color = %s \n", kColorChg, S_ID, SColor

kDur		=		10
;kColorChg	=		trigger(gktime, 1, 0)

if	kColorChg == 1	then
 gSfilename1	sprintfk	"%s%s_%sWheels.txt", SPath, S_ID, SColor;, SDate
 gSfilename2	sprintfk	"%s%s_%sBack.txt", SPath, S_ID, SColor;, SDate
		event	"i", SColor, 5, kDur
		event	"i", "recordData", 5, kDur
endif

; Receive euler angles from NGIMU sensors
kdata_34[]	init		10
gkchg_34, kdata_34		OSClisten	giOSCh34, "/euler", "fff"
kdata_35[]	init		3
gkchg_35, kdata_35		OSClisten	giOSCh35, "/euler", "fff"
kdata_36[]	init		3
gkchg_36, kdata_36		OSClisten	giOSCh36, "/euler", "fff"

gkleftWheel	=		kdata_34[0]
gkrightWheel	=	kdata_35[0]
gkchairTilt	=		kdata_36[1]
gkchairDir	=		kdata_36[2]

kLastTime	init		0

; Pre-processing of sensor data

gkd_34[]	init		3
gkd_35[]	init		3
gkd_36[]	init		3
kdeltime	=		0.02
gkd_34	Delta_euler	kdata_34, kdeltime, 0.05


endin


;**********************************************************************
;		Instrument for recording sensor data
;**********************************************************************
		instr		recordData
; Record wheel data
if (gkchg_34 + gkchg_35) == 1 then
		dumpk3  	gktime, gkleftWheel, gkrightWheel,  gSfilename1, 8, 0
endif
; Record back sensor data
if gkchg_36==1	then
		dumpk3  	gktime, gkleftWheel, gkrightWheel,  gSfilename2, 8, 0
endif
endin

;**********************************************************************
;		Sonification instrument 1
;**********************************************************************
		instr		red

aOsc		oscil		gkd_34[0], 200+gkd_34[0]
		outs		aOsc, aOsc

		endin

;**********************************************************************
;		Sonification instrument 2
;**********************************************************************
		instr		green

aOsc		oscil		gkd_34[0], 300+gkd_34[0]
		outs		aOsc, aOsc

		endin


;**********************************************************************
;		Sonification instrument 3
;**********************************************************************

		instr		blue

aOsc		oscil		gkd_34[0], 400+gkd_34[0]
		outs		aOsc, aOsc

		endin


;**********************************************************************
;		Sonification instrument 4
;**********************************************************************

		instr		yellow

aOsc		oscil		gkd_34[0], 500+gkd_34[0]
		outs		aOsc, aOsc

		endin


</CsInstruments>
<CsScore>

</CsScore>
</CsoundSynthesizer>