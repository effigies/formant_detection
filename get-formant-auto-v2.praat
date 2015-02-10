##	takes directory of sound files and loops through them
##  calculating the mean f1 and f2 values around the maxima f1 & f2
##

a_START_ZONE = 0.2
a_END_ZONE = 0.8

clearinfo

form Input Enter directory and output file name
   	comment Enter directory where soundfiles are kept:
    	sentence directory C:\Users\jgyou\Desktop\stimuli_sample\speaker1
    	comment Enter directory for output file:
    	sentence listDir C:\Users\jgyou\Desktop\stimuli_sample\speaker1
    	comment Enter name of output file:
    	sentence outFile formant-values-auto.txt
	comment Enter minimal intensity (dB):
	real min_intensity 70.0
	comment Enter maximum formant (male = 5000, female = 5500)
	integer maxForm 5500
	comment Enter window length (s)
	real windLength 0.025
endform

strings = Create Strings as file list: "list", directory$ + "/*.wav"
numberOfFiles = Get number of strings

writeInfoLine: directory$


# loops through .wav files and outputs F1, F2 values
for ifile to numberOfFiles
    
	## choose sound file for analysis
	selectObject: strings
    	fileName$ = Get string: ifile
	fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)
	Read from file: directory$ + "/" + fileName$
	
	## cut down sound file and find maximum intensity
	
	max_intensity = 0
	t = 0
	selectObject: "Sound " + fileNameAbbrev$
	total_time = Get total duration
	View & Edit
	editor: "Sound " + fileNameAbbrev$
		Select: a_START_ZONE*total_time, a_END_ZONE*total_time
		max_intensity = Get maximum intensity
		Extract selected sound (preserve times)
	endeditor
	minusObject: "Sound " + fileNameAbbrev$
	removeObject: "Sound " + fileNameAbbrev$
	
	## variable set up

	selectObject: "Sound untitled"
	fileNameAbbrev$ = fileNameAbbrev$ + "a"
	Rename: fileNameAbbrev$
	start_time = Get start time
	end_time = Get end time
	
	t_intensity = 0
	t = end_time
	minusObject: "Sound " + fileNameAbbrev$

	## check for false formants due to points on the fringe
	while t_intensity < 0.5*max_intensity
	
	## choose appropriate time interval and export formant
	selectObject: "Sound " + fileNameAbbrev$
	View & Edit
	editor: "Sound " + fileNameAbbrev$
		Select: start_time, t
		local_max_intensity = Get maximum intensity
		if abs(local_max_intensity - max_intensity) > 10
			t = t + 0.01
			start_time = t
			appendInfoLine: "global max " + string$(max_intensity) + " local max " + string$(local_max_intensity) 
			Select: t, end_time
		else
			t = t - 0.01
			end_time = t
			Select: start_time, t
			appendInfoLine: "Choosing times"
			appendInfoLine: start_time
			appendInfoLine: t
			appendInfoLine: "global max " + string$(max_intensity) + " local max " + string$(local_max_intensity) 
		endif
		Zoom to selection
		Extract visible formant contour
	endeditor
	minusObject: "Sound " + fileNameAbbrev$
	
	## select Formant object and get appropriate time
	selectObject: "Formant untitled"
	formantName$ = replace$(fileNameAbbrev$, "Sound ", "", 1)
	formantName$ = formantName$ + "a"
	Rename: formantName$
	t = Get time of maximum: 1, 0,  0, "Hertz", "None"
	removeObject: "Formant " + formantName$
	
	## then get intensity of formant
	editor: "Sound " + fileNameAbbrev$ 
	Move cursor to: t
	t_intensity = Get intensity

	appendInfoLine: "Intensity"
	appendInfoLine: t_intensity
	appendInfoLine: t
	endeditor

	endwhile
	
	## get F1, F2 averages
	selectObject: "Sound " + fileNameAbbrev$
	select_end = Get end time
	select_start = Get start time
	View & Edit
	editor: "Sound " + fileNameAbbrev$
		if t + 0.025 > select_end
			Select: t - 0.025, select_end
		elif t - 0.025 < select_start
			Select: select_start, t + 0.025
		else
			Select: t - 0.025, t + 0.025	
		endif
		
		Formant settings: maxForm, 5, windLength, 30.0, 1.0
		v1f1 = Get first formant
		v1f2 = Get second formant
		fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' 't:8' 'tab$'  'v1f1:5' 'tab$'  'v1f2:5' 'newline$' 
		appendInfoLine: fileNameAbbrev$
		appendInfoLine: "time :" + string$(t-0.025) +  " - " + string$(t+0.025)
		appendInfoLine: v1f1
		appendInfoLine: v1f2
	endeditor
	
	select all
	minusObject: strings
    	Remove
endfor

appendInfoLine: "***Formant analysis complete***"

