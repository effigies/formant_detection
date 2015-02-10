form Input Enter directory and output file name
   	comment Enter directory where soundfiles are kept:
    	sentence directory C:\Users\jgyou\Desktop\stimuli_sample\speaker1
    	comment Enter directory for output file:
    	sentence listDir C:\Users\jgyou\Desktop\stimuli_sample\speaker1
    	comment Enter name of output file:
    	sentence outFile formant-values-auto-v1-TEST.txt
	comment Enter maximum formant (male = 5000, female = 5500)
	integer maxForm 5500
	comment Enter window length (s)
	real windLength 0.025
endform

strings = Create Strings as file list: "list", directory$ + "/*.wav"
numberOfFiles = Get number of strings


# loops through .wav files and creates a TextGrid - then opens them up together
for ifile to numberOfFiles
    	selectObject: strings
    	fileName$ = Get string: ifile
	fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)
    	Read from file: directory$ + "/" + fileName$
	To TextGrid: "time", ""
	Save as text file: directory$ + "\" + fileNameAbbrev$ + ".TextGrid"
	appendInfoLine: fileNameAbbrev$
	
	## Find maximum intensity
	selectObject: "Sound " + fileNameAbbrev$
	To Intensity: 100, 0, 0
	selectObject: "Intensity " + fileNameAbbrev$
	t = Get time of maximum: 0, 0, "None"
	minusObject: "Intensity " + fileNameAbbrev$
	
	## create text grid
	selectObject: "Sound " + fileNameAbbrev$
	plusObject: "TextGrid " + fileNameAbbrev$
	View & Edit
	editor: "TextGrid " + fileNameAbbrev$
		Select: t - 0.025, t + 0.025
		Formant settings: maxForm, 5, windLength, 30.0, 1.0
		v1f1 = Get first formant
		v1f2 = Get second formant
		fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' 't:5' 'tab$'  'v1f1:5' 'tab$'  'v1f2:5' 'newline$' 
		appendInfoLine: v1f1
		appendInfoLine: v1f2
	endeditor
	
	select all
	minusObject: strings
    	Remove
endfor