##	takes directory of sound files and loops through them
##  calculating the mean F1, F2, and F3 values around a user-designated midpoint
## 	also outputs vowel, time of midpoint and the average pitch of the file
##

clearinfo

## prompt
form Input Enter directory and output file name
		comment Enter directory where soundfiles are kept:
    	sentence directory C:\DATA\FMRI_AUDIO\recordings\NWR_001\parsed\misc\has_vowel
    	comment Enter directory for output file:
    	sentence listDir C:\DATA\FMRI_AUDIO\recordings\NWR_001\parsed\misc\has_vowel
    	comment Enter name of output file:
    	sentence outFile formant-values-auto-v4.txt
		comment Choose gender
		choice gender:
			button M
			button F
	comment Enter window length for formants
	real windLength 0.025
endform

## gender-dependent variables
maxForm = 0
pitchFloor = 0
pitchCeiling = 0

if gender$ = "M"
	maxForm = 5000
	pitchFloor = 75
	pitchCeiling = 300
else
	maxForm = 5500
	pitchFloor = 100
	pitchCeiling = 500
endif

## receive list of files
strings = Create Strings as file list: "list", directory$ + "/*.wav"
numberOfFiles = Get number of strings
writeInfoLine: directory$

## header for file	
fileappend 'listDir$'\'outFile$' 'gender$' - 'listDir$' 'newline$'
fileappend 'listDir$'\'outFile$' File Name 'tab$' vowel 'tab$' time (sec) 'tab$' F1 'tab$' F2 'tab$' F3 'tab$' Pitch 'newline$'

## loops through .wav files and outputs F1, F2 values
for ifile to numberOfFiles
    
	## choose sound file for analysis
	selectObject: strings
    fileName$ = Get string: ifile
	fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)
	fileNameAbbrev$ = replace$(fileNameAbbrev$, ".", "_", 0)
	Read from file: directory$ + "/" + fileName$
	
	## determine syllable being processed based on file name
	word$ = left$(fileNameAbbrev$, 3)
	midchar$ = mid$(word$, 2, 1)

	
	selectObject: "Sound " + fileNameAbbrev$
	file_duration = Get total duration
	#Extract part: 0.1*file_duration, 0.9*file_duration, "rectangular", 1.0, 1
	View & Edit
	#fileNameAbbrev$ = fileNameAbbrev$ + "_part"
	
	## sound editor opens to allow user to choose midpoint of vowel for calculating F1->F3
	editor: "Sound " + fileNameAbbrev$
		Formant settings: maxForm, 5.0, windLength, 30.0, 1.0
		beginPause: "Choose midpoint of vowel for formant on editor and click Continue"
		buttonChosen = endPause: "Continue", "Skip", "Invalid file", 0
		#endPause: "Continue", 0
		t = Get cursor
	endeditor
 
	## click on Continue to view next sound file
	if buttonChosen = 1
	
		## calculates F1, F2, F3
		To Formant (burg): 0, 5, maxForm, windLength, 70
		selectObject: "Formant " + fileNameAbbrev$

		v1f1 = Get mean: 1, t - 0.035, t + 0.035, "Hertz"
		v1f2 = Get mean: 2, t - 0.035, t + 0.035, "Hertz"
		v1f3 = Get mean: 3, t - 0.035, t + 0.035, "Hertz"
		#v1f1 = Get quantile: 1, t - 0.035, t + 0.035, "Hertz", 0.5
		#v1f2 = Get quantile: 2, t - 0.035, t + 0.035, "Hertz", 0.5
		#v1f3 = Get quantile: 3, t - 0.035, t + 0.035, "Hertz", 0.5
	
		## find pitch
		removeObject: "Formant " + fileNameAbbrev$
		selectObject: "Sound " + fileNameAbbrev$
		To Pitch: 0, pitchFloor, pitchCeiling
		pitch = Get mean: 0, 0, "Hertz"
	
		## output results
		fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' 'midchar$' 'tab$' 't:8' 'tab$'  'v1f1:8' 'tab$'  'v1f2:8' 'tab$'  'v1f3:8' 'tab$' 'pitch:8' 'newline$' 

	elif buttonChosen = 2
		fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' 'midchar$' 'tab$' Skipped or separately checked 'newline$' 
	else
		## allows for skipping files
		## skip option available for empty sound files/other scenarios
		fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' 'midchar$' 'tab$' Invalid file 'newline$' 
	endif	

	select all
	minusObject: strings
    Remove
endfor

appendInfoLine: "***Formant analysis complete***"

