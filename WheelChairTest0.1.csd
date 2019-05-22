	<CsoundSynthesizer>
<CsOptions>
-odac1 -b128 -B256 -m0 -d ;--realtime
</CsOptions>

<CsInstruments>
; Denne versjonen ble brukt på VIBRA workshop 2, Verkstedhallen 15.mai 2018 med:
; VIBRA-Spat_0.1.maxpat og VIBRA_Mixer2.maxpat
/*
TODO:
- Lage et system for å kunne skru av de instrumentene som evt. jeg har glemt å skru av
- Lage et system for å enkelt kunne lagre presets og bytte mellom disse (preset i Max feilet):
- Ha et eget instrument som sjekker hvilke instrument som er på og med hvilke innstillinger
og sende dette til GUI, der de kan skrus av
- Lage mer fleksible lyd-instrument der det kan interpoleres mer fleksibelt mellom ulike lydtyper
F.eks. kombinere multimincer (tabell kan skiftes ut på k-tid og kan derfor også ta forsinka
sanntidsinput) med flere instanser av partikkel - er det mulig å kjøre (og koordinere) fire instanser
(og dermed 32 kanaler/objekter) samtidig?
- Sjekke ut Boids - http://www.vergenet.net/~conrad/boids/pseudocode.html for å styre lydobjekt
- Sette opp automasjon + "intelligens" + parameter fra dansere som kan styre flere lydparameter,
også de på mer metanivå
- Implementere spatialisering som flere instrument i stedet for bare ett. Da kan de lettere ta over
sømløst fra hverandre (fade inn og ut azi og dist verdier)
mincer

*/
;**************************************************************************************************
sr		=		44100	; Sample rate matches sound files
ksmps		=		16	; Samples per control period - gives a kr period of 1.33ms
nchnls	=		8	; 8-chnls
0dbfs		=		1	; Maximum 0dB reference level
;**************************************************************************************************
;		INITIATE GLOBAL VARIABLES AND CHANNELS, FTABLES AND GUI
;**************************************************************************************************
#define	ALWAYSON		#9999999#

; Declare channels for communication with Max
#include		"Inc/MaxSndChnls.inc"

; Set to 0 when running whole VIBRA setup, for testing with single sensors, set to 1
gkTesting		init			0


; Initiate python
		pyinit

/*_____________________________________________________________________________________________
 INITIATE OSC PORTS FOR COMMUNICATION WITH CONTROL (CM) MODULES
*/
giMainPort	=			7000
giCMserver	OSCinit		giMainPort
giNGIMU37	OSCinit		8034
giNGIMU36	OSCinit		8036
giCMserver2	OSCinit		5432			; Port for sending data from 4th armband to Sigurd
giMyoTest	OSCinit		5431
giMax		OSCinit		3000

giNGIMU4	OSCinit		8001

;_____________________________________________________________________________________________

;==========================================================================================
;==========================================================================================
;==========================================================================================
; 	INCLUDE UDOs SECTION
;==========================================================================================
;==========================================================================================
;==========================================================================================
#include "/Users/andber/Particles/MC3.0/Inc/Udo/Debounce.udo"

; UDO that lists the names of the folders in a folder, here the set names
;#include "/Users/andber/Particles/MC3.0/Inc/Udo/GetFolderNames.udo"

;#include "/Users/andber/Particles/MC3.0/Inc/Udo/ReadAndSortFiles.udo"

#include "/Users/andber/Particles/MC3.0/Inc/Udo/Metro_a.udo"

#include "Inc/Onsets_k.udo"

#include "Inc/OSClistenArray.udo"

#include "Inc/Portk_array.udo"

#include "Inc/MapTab_array.udo"

#include "Inc/EMGwarbler_array.udo"

#include "Inc/Accel_intensity.udo"

#include "Inc/Spatialize.udo"

#include "Inc/Delta_array.udo"

#include "Inc/Delta_euler.udo"

#include "Inc/MultiMetro.udo"

		seed		0

giSine	ftgen		0, 0, 2^18, 10, 1
giFadePart  ftgen		0, 0, 1024, 5, 1, 400, 0.05, 624, 0.000001
giMaxAmps	ftgen		0, 0, 256, -7, 0
giMaxFrqs	ftgen		0, 0, 256, -7, 0

giIR_maxlen	=	8192*4	; Just over a second
giIR_record 	ftgen 	0, 0, giIR_maxlen, 2, 1, 0

gaSend[]	init		8
gkAzi[]	init		8
gkDist[]	init		8
gkSpread[]	init		8

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;		Receive OSC-data from motion tracking system, cook/prepare global parameters
;		Manage sound sets 1 and 2 for one and two player modes
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

			instr		1

;-----------Make tables section--------------------------------
SFiles[]	directory	"/Users/andber/Desktop/VIBRA/Teknisk/Csound/SND", ".wav"
giNumFiles	lenarray	SFiles
print		giNumFiles

; Make tables with sound files, store table numbers in an array
giTabNums[]		init			giNumFiles
giTabLengths[]	init			giNumFiles
indx1			=			0

maketables:
    ifn			ftgentmp		0, 0, 0, 1, SFiles[indx1], 0, 0, 1	; Read files as mono
    giTabNums[indx1]	=			ifn
    ilen			=			ftlen(ifn)
    giTabLengths[indx1]	=			ilen
loop_lt	indx1, 1, giNumFiles, maketables

; Keep track of categories of FM-recordings----------------------------------------
iNumCats		=			7
giCategories[][]	init			iNumCats, 30	; Use 7 categories: Kunst, Musikk, Nyheter, rePortasje, Reklame, Show og Utenriks
									; each with space for 30 ftable numbers
indxcat			=		0
indxftnums			=		1
indx2				=		0	; Index to iterate through the array
SLastCat			strcpy		""			; initiate as empty string
countmembers:
    SCategory		strsub		SFiles[indx2], 58, 59
    iCompare		strcmp		SCategory, SLastCat
    if	indx2 == giNumFiles-1		then
        giCategories[indxcat][0]=		indxftnums
    elseif	iCompare 	!= 0	&& indx2 != 0	then		; When current is different from last...
        giCategories[indxcat][0]=		indxftnums-1      ; write the number of members in the category to the first index
        indxcat		+=			1			; change category....
        indxftnums	=			1			; and reset index for ftable numbers
    endif
    giCategories[indxcat][indxftnums] =	giTabNums[indx2]
;    print indxcat, indxftnums, giTabNums[indx2]
    SLastCat		strcpy		SCategory
    indxftnums		+=			1
loop_lt	indx2, 1, giNumFiles, countmembers

if	gkTesting == 1	goto contin
; Send message to connect to server
kTrig		init		1
		OSCsend	kTrig, "192.168.1.39", 32000, "/vibra/connect", "si", "192.168.1.40", giMainPort
kTrig		=		0
;-------------------------------------------------------------------------------
contin:
endin

	instr 	2

; Get volum controls from Max
iStartVol		=			-15
gkVolumMyo1		init			iStartVol
gkVolumMyo2		init			iStartVol
gkVolumMyo3		init			iStartVol
gkVolumMyo4		init			iStartVol
gkVolumNGIMU1	init			iStartVol
gkVolumNGIMU2	init			iStartVol
gkVolumNGIMU3	init			iStartVol
gkVolumNGIMU4	init			iStartVol

kans			OSClisten		giMax, "/myo/1/volume", "f", gkVolumMyo1
kans			OSClisten		giMax, "/myo/2/volume", "f", gkVolumMyo2
kans			OSClisten		giMax, "/myo/3/volume", "f", gkVolumMyo3
kans			OSClisten		giMax, "/myo/4/volume", "f", gkVolumMyo4
kans			OSClisten		giMax, "/ngimu/1/volume", "f", gkVolumNGIMU1
kans			OSClisten		giMax, "/ngimu/2/volume", "f", gkVolumNGIMU2
kans			OSClisten		giMax, "/ngimu/3/volume", "f", gkVolumNGIMU3
kans			OSClisten		giMax, "/ngimu/4/volume", "f", gkVolumNGIMU4

gkVolume[]		init			8
gkVolume[0]		=			1;ampdb(gkVolumMyo1)
gkVolume[1]		=			ampdb(gkVolumMyo2)
gkVolume[2]		=			ampdb(gkVolumMyo3)
gkVolume[3]		=			ampdb(gkVolumMyo4)
gkVolume[4]		=			ampdb(gkVolumNGIMU1)
gkVolume[5]		=			ampdb(gkVolumNGIMU2)
gkVolume[6]		=			ampdb(gkVolumNGIMU3)
gkVolume[7]		=			ampdb(gkVolumNGIMU4)

gkSpatMode[]	init		8
gkSpatMode		OSClistenArray	giMax, "/spatmode", "iiiiiiii"

; Myo armbands - raw IMU data-----------------------------------------------------
; AccelsXYZ
gkMyo1_Accel[]	init		3
gkMyo1_Accel	OSClistenArray	giCMserver, "/myo/1/acceleration/raw", "fff"

if		gkTesting == 1	then
gkMyo1_Accel	OSClistenArray	giMyoTest, "/myo1/acceleration/raw", "fff"
endif


gkMyo1_Acc_ints[]	init			3
gkMyo1_Acc_ints, gkMyo1_Acc_int	Accel_intensity	gkMyo1_Accel
;printk	0.25, gkMyo1_Accel[1]

gkMyo2_Accel[]	init		3
gkMyo2_Accel	OSClistenArray	giCMserver, "/myo/2/acceleration/raw", "fff"
gkMyo2_Acc_ints[]	init			3
gkMyo2_Acc_ints, gkMyo2_Acc_int	Accel_intensity	gkMyo2_Accel

gkMyo3_Accel[]	init		3
gkMyo3_Accel	OSClistenArray	giCMserver, "/myo/3/acceleration/raw", "fff"
gkMyo3_Acc_ints[]	init			3
gkMyo3_Acc_ints, gkMyo3_Acc_int	Accel_intensity	gkMyo3_Accel

gkMyo4_Accel[]	init		3
gkMyo4_Accel	OSClistenArray	giCMserver, "/myo/4/acceleration/raw", "fff"
gkMyo4_Acc_ints[]	init			3
gkMyo4_Acc_ints, gkMyo4_Acc_int	Accel_intensity	gkMyo4_Accel


; GyroXYZ
gkMyo1_Gyro[]	init		3
gkMyo1_Gyro	OSClistenArray	giCMserver, "/myo/1/gyro/raw", "fff"		; 
if	gkTesting == 1	then
gkMyo1_Gyro	OSClistenArray	giMyoTest, "/myo1/gyro/raw", "fff"
endif
;printk	0.25, gkMyo1_Gyro[0]

gkMyo2_Gyro[]	init		3
gkMyo2_Gyro	OSClistenArray	giCMserver, "/myo/2/gyro/raw", "fff"

gkMyo3_Gyro[]	init		3
gkMyo3_Gyro	OSClistenArray	giCMserver, "/myo/3/gyro/raw", "fff"

; Use this line when connected to vibra.speed
gkMyo4_Gyro[]	init		3
gkMyo4_Gyro	OSClistenArray	giCMserver, "/myo/4/gyro/raw", "fff"

; Myo armbands - IMU-based intensity----------------------------------------------
gkMyo1_Acc_delta[] init		3
gkMyo1_Acc_delta	OSClistenArray	giCMserver, "/myo/1/acceleration/scaled", "fff"
if		gkTesting == 1	then
gkMyo1_Acc_delta	OSClistenArray	giMyoTest, "/myo1/acceleration/scaled", "fff"
endif
;kMyo1_Acc_Abs[]	init		3
;kMyo1_Acc_Abs	maparray	gkMyo1_Acc_delta, "abs"
;gkMyo1_Acc_int	sumarray	kMyo1_Acc_Abs
;
gkMyo2_Acc_delta[] init		3
gkMyo2_Acc_delta	OSClistenArray	giCMserver, "/myo/2/acceleration/scaled", "fff"

gkMyo3_Acc_delta[] init		3
gkMyo3_Acc_delta	OSClistenArray	giCMserver, "/myo/3/acceleration/scaled", "fff"

gkMyo4_Acc_delta[] init			3
gkMyo4_Acc_delta	OSClistenArray	giCMserver, "/myo/4/acceleration/scaled", "fff"


;
; Myo armbands - IMU-based euler calculations---------------------------------------
gkMyo1_euler[]	init		3
gkMyo1_euler	OSClistenArray	giCMserver, "/myo/1/orientation/raw", "fff" ; fra -pi til +pi (yaw, pitch roll)

if	gkTesting == 1	then
gkMyo1_euler	OSClistenArray	giMyoTest, "/myo1/orientation/raw", "fff"
endif

gkMyo2_euler[]	init		3
gkMyo2_euler	OSClistenArray	giCMserver, "/myo/2/orientation/raw", "fff"

gkMyo3_euler[]	init		3
gkMyo3_euler	OSClistenArray	giCMserver, "/myo/3/orientation/raw", "fff"

gkMyo4_euler[]	init		3
gkMyo4_euler	OSClistenArray	giCMserver, "/myo/4/orientation/raw", "fff"

; Myo armbands - IMU-based quaternions--Finnes ikke på MyoMapper v.2, bare v.3
gkMyo1_quats[]	init		4
gkMyo1_quats	OSClistenArray	giCMserver, "/myo/1/orientation/quaternion", "ffff"

if	gkTesting == 1	then
gkMyo1_quats	OSClistenArray	giCMserver, "/myo1/orientation/quaternion", "ffff"
endif

gkMyo2_quats[]	init		4
gkMyo2_quats	OSClistenArray	giCMserver, "/myo/2/orientation/quaternion", "ffff"

gkMyo3_quats[]	init		4
gkMyo3_quats	OSClistenArray	giCMserver, "/myo/3/orientation/quaternion", "ffff"

gkMyo4_quats[]	init		4
gkMyo4_quats	OSClistenArray	giCMserver, "/myo/4/orientation/quaternion", "ffff"


; Myo armbands - filtered EMG data--------------------------------------------
gkMyo1_EMG_bf[]	init		8
gkMyo1_EMG_bf	OSClistenArray	giCMserver, "/myo/1/EMG/scaledAbs", "ffffffff"


gkMyo2_EMG_bf[]	init		8
gkMyo2_EMG_bf	OSClistenArray	giCMserver, "/myo/2/EMG/scaledAbs", "ffffffff"

gkMyo3_EMG_bf[]	init		8
gkMyo3_EMG_bf	OSClistenArray	giCMserver, "/myo/3/EMG/scaledAbs", "ffffffff"

; This is the EMG that is connected to my machine ID: Myo1
gkMyo4_EMG_bf[]	init		8
gkMyo4_EMG_bf	OSClistenArray	giCMserver, "/myo/4/emg/scaled/abs", "ffffffff"

; Use these lines for testing away from Vibra.speed, testing with Myo Mapper 3
if	gkTesting	==	1	then
gkMyo1_EMG_bf	OSClistenArray	giMyoTest, "/myo1/emg/scaled/abs", "ffffffff"
endif

;printk2		gkMyo4_EMG_bf[0]
; Myo armbands - sum of filtered EMG data-------------------------------------
;gkMyo1_EMG_sum	init		0
;kans			OSClisten		giCMserver, "/myo/1/emg/bfilt/sum", "f", gkMyo1_EMG_sum
;gkMyo1_EMG_sum	port		gkMyo1_EMG_sum, 0.02
kMyo1_EMG_sum	sumarray		gkMyo1_EMG_bf				
gkMyo1_EMG_sum	=			kMyo1_EMG_sum * 0.125			; Calculate normalized sum of array

;gkMyo2_EMG_sum	init		0
;gkans			OSClisten		giCMserver, "/myo/2/emg/bfilt/sum", "f", gkMyo2_EMG_sum
;gkMyo2_EMG_sum	port		gkMyo2_EMG_sum, 0.02
kMyo2_EMG_sum	sumarray		gkMyo2_EMG_bf				
gkMyo2_EMG_sum	=			kMyo2_EMG_sum * 0.125			; Calculate normalized sum of array

;gkMyo3_EMG_sum	init		0
;kans			OSClisten		giCMserver, "/myo/3/emg/bfilt/sum", "f", gkMyo3_EMG_sum
kMyo3_EMG_sum	sumarray		gkMyo3_EMG_bf				
gkMyo3_EMG_sum	=			kMyo3_EMG_sum * 0.125			; Calculate normalized sum of array

;gkMyo4_EMG_sum	init		0
;kans			OSClisten		giCMserver, "/myo/4/emg/bfilt/sum", "f", gkMyo4_EMG_sum
kMyo4_EMG_sum	sumarray		gkMyo4_EMG_bf				
gkMyo4_EMG_sum	=			kMyo4_EMG_sum * 0.125			; Calculate normalized sum of array
;gkMyo4_EMG_sum	port			gkMyo4_EMG_sum, 0.02

; Myo armbands - relative data-------------------------------------------------------------
; Angular difference - when armbands turn different ways => positive, opposite ways => negative
gkMyo1_2_ang_diff	init		0
kan			OSClisten		giCMserver, "/myo/1_2/euler/ang_diff", "f", gkMyo1_2_ang_diff

gkMyo3_4_ang_diff	init		0
kan			OSClisten		giCMserver, "/myo/1_2/euler/ang_diff", "f", gkMyo3_4_ang_diff

; Angular sum - when armbands turn same ways left => high positive values, same ways right => high negative values
gkMyo1_2_ang_sum	init		0
kan			OSClisten		giCMserver, "/myo/3_4/euler/ang_sum", "f", gkMyo1_2_ang_sum

gkMyo3_4_ang_sum	init		0
kan			OSClisten		giCMserver, "/myo/3_4/euler/ang_sum", "f", gkMyo3_4_ang_sum


; NGIMU sensors Euler angles --------------------------------------

gkEuler[]		init		3
kans, gkEuler	OSClisten	giNGIMU37, "/euler", "fff"
gkLinear[]		init		3
kans, gkLinear 	OSClisten	giNGIMU37, "/linear", "fff"

gkEuler2[]		init		3
kans, gkEuler2	OSClisten	giNGIMU36, "/euler", "fff"

;printk2	gkEuler2[0]


gkNGIMU1_Eul[]	init		3
gkNGIMU1_Eul	OSClistenArray	giCMserver, "/ngimu/1/euler", "fff"

gkNGIMU2_Eul[]	init		3
gkNGIMU2_Eul	OSClistenArray	giCMserver, "/ngimu/2/euler", "fff"

gkNGIMU3_Eul[]	init		3
gkNGIMU3_Eul	OSClistenArray	giCMserver, "/ngimu/3/euler", "fff"

gkNGIMU4_Eul[]	init		3
gkNGIMU4_Eul	OSClistenArray	giCMserver, "/ngimu/4/euler", "fff"

if	gkTesting == 1	then
gkNGIMU4_Eul	OSClistenArray	giNGIMU4, "/euler", "fff"
endif

; NGIMU quaternions
gkNGIMU1_Quats[]	init		4
gkNGIMU1_Quats	OSClistenArray	giCMserver, "/ngimu/1/quaternion", "ffff"

gkNGIMU2_Quats[]	init		4
gkNGIMU2_Quats	OSClistenArray	giCMserver, "/ngimu/2/quaternion", "ffff"

gkNGIMU3_Quats[]	init		4
gkNGIMU3_Quats	OSClistenArray	giCMserver, "/ngimu/3/quaternion", "ffff"

gkNGIMU4_Quats[]	init		4
gkNGIMU4_Quats	OSClistenArray	giCMserver, "/ngimu/4/quaternion", "ffff"

if	gkTesting == 1	then
gkNGIMU4_Quats	OSClistenArray	giNGIMU4, "/quaternion", "ffff"
endif
;--------------------------------------------------
;printk2	gkNGIMU1_Eul[0] ; (Roll, pitch, yaw)
;kcpslast	init		0
;kcps		=		gkNGIMU1_Eul[1]
; This code is for correcting jumps in the values - does not work well when dancers roll on the floor.
;if	(kcps - kcpslast) > 300	then
;kcps		=	kcps - 360
;elseif (kcps - kcpslast) < -300	then
;kcps		=	kcps + 360
;endif
;out(oscil(0.2, 400+kcps*2))
;kcpslast	=		kcps
;printk2	kcps

; NGIMU sensors IMU data--------------------------------------
gkNGIMU1_IMU[]	init		10
gkNGIMU1_IMU	OSClistenArray	giCMserver, "/ngimu/1/sensors", "ffffffffff"
gkNGIMU1_gyro[]	init		3
gkNGIMU1_gyro[]	slicearray	gkNGIMU1_IMU, 0, 2
gkNGIMU1_mags[]	OSClistenArray	giCMserver, "/ngimu/1/magnitudes", "fff"
gkNGIMU1_acc[]	init		3
gkNGIMU1_acc[]	slicearray	gkNGIMU1_IMU, 3, 5
gkNGIMU1_aInts[]	init		3
gkNGIMU1_aInts, gkNGIMU1_aInt	Accel_intensity	gkNGIMU1_acc


gkNGIMU2_IMU[]	init		10
gkNGIMU2_IMU	OSClistenArray	giCMserver, "/ngimu/2/sensors", "ffffffffff"
gkNGIMU2_gyro[]	init		3
gkNGIMU2_gyro[]	slicearray	gkNGIMU2_IMU, 0, 2
gkNGIMU2_mags[]	OSClistenArray	giCMserver, "/ngimu/2/magnitudes", "fff"
gkNGIMU2_acc[]	init		3
gkNGIMU2_acc[]	slicearray	gkNGIMU2_IMU, 3, 5
gkNGIMU2_aInts[]	init		3
gkNGIMU2_aInts, gkNGIMU2_aInt	Accel_intensity	gkNGIMU2_acc

gkNGIMU3_IMU[]	init		10
gkNGIMU3_IMU	OSClistenArray	giCMserver, "/ngimu/3/sensors", "ffffffffff"
gkNGIMU3_gyro[]	init		3
gkNGIMU3_gyro[]	slicearray	gkNGIMU3_IMU, 0, 2
gkNGIMU3_mags[]	OSClistenArray	giCMserver, "/ngimu/3/magnitudes", "fff"
gkNGIMU3_acc[]	init		3
gkNGIMU3_acc[]	slicearray	gkNGIMU3_IMU, 3, 5
gkNGIMU3_aInts[]	init		3
gkNGIMU3_aInts, gkNGIMU3_aInt	Accel_intensity	gkNGIMU3_acc

gkNGIMU4_IMU[]	init		10
if gkTesting	==	1	then
gkNGIMU4_IMU	OSClistenArray	giNGIMU4, "/sensors", "ffffffffff"
else
gkNGIMU4_IMU	OSClistenArray	giCMserver, "/ngimu/4/sensors", "ffffffffff"
endif
gkNGIMU4_gyro[]	init		3
gkNGIMU4_gyro[]	slicearray	gkNGIMU4_IMU, 0, 2
gkNGIMU4_mags[]	OSClistenArray	giCMserver, "/ngimu/4/magnitudes", "fff"
gkNGIMU4_acc[]	init		3
gkNGIMU4_acc[]	slicearray	gkNGIMU4_IMU, 3, 5
gkNGIMU4_aInts[]	init		3
gkNGIMU4_aInts, gkNGIMU4_aInt	Accel_intensity	gkNGIMU4_acc

if	gkTesting == 1	then
gkNGIMU4_mags[]	OSClistenArray	giNGIMU4, "/magnitudes", "fff"
endif
;printk	0.25, gkNGIMU4_mags[0]

gkNGIMU4_acc[]	init		3
gkNGIMU4_acc	slicearray	gkNGIMU4_IMU, 3, 5
gkNGIMU4_ints[]	init		3
gkNGIMU4_ints, gkNGIMU4_int	Accel_intensity	gkNGIMU4_acc


; NGIMU sensors gyro based intensity--------------------------
;gkNGIMU1_Int	init		0
;kans			OSClisten		giCMserver, "/ngimu/1/imu/int", "f", gkNGIMU1_Int
;
;gkNGIMU2_Int	init		0
;kans			OSClisten		giCMserver, "/ngimu/2/imu/int", "f", gkNGIMU2_Int
;
;gkNGIMU3_Int	init		0
;kans			OSClisten		giCMserver, "/ngimu/3/imu/int", "f", gkNGIMU3_Int

;printk2		gkNGIMU3_Int

iArrLen	lenarray	gkMyo1_EMG_bf

; Do filtering on EMG array
kHalfTime	=		0.02
kMyo_EMG_po[]	Portk_array		gkMyo1_EMG_bf, kHalfTime


endin

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/*
			MAPPING SECTION
Sensor 0: MC/EC
Sensor 1: Myo 1
Sensor 2: Myo 2
Sensor 3: Myo 3
Sensor 4: Myo 4
Sensor 5: NGIMU 1
Sensor 6: NGIMU 2
Sensor 7: NGIMU 3

One instrument establishes a mapping between one/two sensors and one instrument

Parameters for the sound playing instruments are general, to make for easier remapping:
1. Energy articulation (intensity).
2. Sound variation (choice of sound segment: could control a. file index and b. skip time)
3. Modulation (could control, in decreasing order dependent on importance : a. rate, b. depth 0-1, 
							c. skew/dur of "grain" 0.001-4, d.attack/decay factor 0.5, e.shape 0= soft, 1=hard/square)
4. Pitch/transposition
5. Timbre (could control: a. brightness dull: -1, bright: 1, b.noise/tone noise: -1, tone: 1, c. dense/sparse sparse: -1, dense 1, d. wide/narrow narrow -1, wide: 1)
6. Placement (could control: a.panning/azimuth angle in degrees 90=front, b.distance in metres, c. width 0-1, d.variation 1-)
*/
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; Instrument for initializing global arrays and variables to store parameter values

			instr		Launcher
prints	"Launcher launched\n"

; Control messages from VIBRA mixer in Max running locally------------------------
kp1,kp3, kVariant	init		3
kVariant		=		1
kSensor		init		1
kXfade		init		3
k_instrig		OSClisten		giMax, "/instrument", "iifif", kSensor, kp1, kp3,kVariant, kXfade
kInsnum		=		kp1 + 4 + 0.1*kSensor

; Start instrument 4 
schedule		4, 0, $ALWAYSON, 1, 1, 2

gkMetroCps		init		32			; Init at 120 BPM
gkTempoMod		init		0
gkNudge		init		0
gkTempoMod		+=		gkNudge
kTempo		wrap		(gkMetroCps + gkTempoMod), 12, 48
gaMetro, gkMetro 	Metro_a	kTempo
gkMultiMetro[]	init		8
gkMultiMetro[0]	MultiMetro	kTempo, 32
gkMultiMetro[1]	MultiMetro	kTempo, 24
gkMultiMetro[2]	MultiMetro	kTempo, 16
gkMultiMetro[3]	MultiMetro	kTempo, 12
gkMultiMetro[4]	MultiMetro	kTempo, 8
gkMultiMetro[5]	MultiMetro	kTempo, 6
gkMultiMetro[6]	MultiMetro	kTempo, 4
gkMultiMetro[7]	MultiMetro	kTempo, 3


			endin

;/////////////////////////////////////////////////////////////////////////////////////////////////
;		INCLUDE INSTRUMENTS HERE
#include 	"Inc/GirlGeek_AChu.inc"		; instr 4
;#include	"Inc/Myo_minctracer.inc"	; instr 4
;#include	"Inc/Myo_SquineWave.inc"	; instr 5
;#include	"Inc/Myo_MultiSine.inc"		; instr 6
;#include	"Inc/Myo_WarbleSine.inc"	; instr 7
;#include	"Inc/Myo_MultiVoice.inc"	; instr 8
;#include	"Inc/NGIMU_Noizer.inc"		; instr 9
;;
;#include 	"Inc/FlexiPulzer.inc"		; instr 10
;#include	"Inc/Flexi_WarbleSine.inc"
;#include 	"Inc/GirlGeek_AChu.inc"		; instr 11
;#include	"Inc/Flexi_Flow.inc";		; instr 12
;
;#include	"Inc/PulzerTone.inc"
;/////////////////////////////////////////////////////////////////////////////////////////////////

;*******************************************************************************
;		Create spatialization for all sensors
;*******************************************************************************
;#include	"Inc/Spatialization.inc"


;*******************************************************************************
;		Mixer/route/send instrument
;*******************************************************************************
		instr		1000



chnset	gkAzi[0], "azi1"
chnset	gkAzi[1], "azi2"
chnset	gkAzi[2], "azi3"
chnset	gkAzi[3], "azi4"
chnset	gkAzi[4], "azi5"
chnset	gkAzi[5], "azi6"
chnset	gkAzi[6], "azi7"
chnset	gkAzi[7], "azi8"
;
chnset	gkDist[0], "distance1"
chnset	gkDist[1], "distance2"
chnset	gkDist[2], "distance3"
chnset	gkDist[3], "distance4"
chnset	gkDist[4], "distance5"
chnset	gkDist[5], "distance6"
chnset	gkDist[6], "distance7"
chnset	gkDist[7], "distance8"
;
chnset	gkSpread[0], "spread1"
chnset	gkSpread[1], "spread2"
chnset	gkSpread[2], "spread3"
chnset	gkSpread[3], "spread4"
chnset	gkSpread[4], "spread5"
chnset	gkSpread[5], "spread6"
chnset	gkSpread[6], "spread7"
chnset	gkSpread[7], "spread8"

outo		gaSend[0], gaSend[1], gaSend[2], gaSend[3], gaSend[4], gaSend[5], gaSend[6], gaSend[7] 

gaSend[0]	=		0
gaSend[1]	=		0
gaSend[2]	=		0
gaSend[3]	=		0
gaSend[4]	=		0
gaSend[5]	=		0
gaSend[6]	=		0
gaSend[7]	=		0

		endin

</CsInstruments>

<CsScore>
#define	ALWAYSON	#999999#

i1		0		$ALWAYSON
i2		0		$ALWAYSON
i "Launcher"		0		$ALWAYSON
i500		0		$ALWAYSON
i1000		0		$ALWAYSON

</CsScore>

</CsoundSynthesizer>
