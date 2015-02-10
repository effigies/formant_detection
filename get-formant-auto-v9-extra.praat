##	takes directory of sound files and loops through them to calculate F1, F2, F3, and pitch
## 
##	
##  for remaining syllable types: 
## 	finding the section of the sound file with the highest median f1 value
## 	and using that time point as the midpoint from which to calculate F1, 
##	F2, and F3 over a 0.07 sec interval
##
##	in all cases, pitch is an average calculated over entire sound file

clearinfo

## prompt
form Input Enter directory and output file name
   	comment Enter directory where soundfiles are kept:
    	sentence directory C:\DATA\FMRI_AUDIO\recordings\NWR_001\parsed
    	comment Enter directory for output file:
    	sentence listDir C:\DATA\FMRI_AUDIO\recordings\NWR_001\parsed
    	comment Enter name of output file:
    	sentence outFile formant-values-auto-v9.txt
	comment Enter window length for choosing time of F1 values:
	real chooseFWindLength 0.03
	comment Choose gender
		choice gender:
			button M
			button F
	comment Enter window length for formants
	real formantWindLength 0.025
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

## retrieve file list
strings = Create Strings as file list: "list", directory$ + "/*.wav"
numberOfFiles = Get number of strings
writeInfoLine: directory$

## header for file
fileappend 'listDir$'\'outFile$' 'gender$' - 'listDir$' 'newline$'
fileappend 'listDir$'\'outFile$' File Name 'tab$' vowel'tab$' time (sec) 'tab$' F1 'tab$' F2 'tab$' F3 'tab$' Pitch 'tab$' alt time (sec) 'tab$' F1 'tab$' F2 'tab$' F3 'tab$' span of pulse 'newline$'

## loops through .wav files and outputs F1, F2 values
for ifile to numberOfFiles
    
	## choose sound file for analysis
	selectObject: strings
    	fileName$ = Get string: ifile
	fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)
	
	#remove dots that are not allowed in the file name
	fileNameAbbrev$ = replace$(fileNameAbbrev$, ".", "_", 0) 
	Read from file: directory$ + "/" + fileName$
	
	## determine syllable being processed based on file name
	word$ = left$(fileNameAbbrev$, 3)
	first_char$ = mid$(word$, 1, 1)
	last_char$ = right$(word$, 1)
	mid_char$ = mid$(word$, 2, 1)
	
	end_time_sound = Get total duration
	start_time_sound = 0
	hasPoints = 0
	
	#for txl, because intensity slopes down in the vowel, this has to be processed differently
	if not (first_char$ = "t" and last_char$ = "l")
		## convert Sound to PointProcess (pulses) to obtain relevant time area in file to focus on

		selectObject: "Sound " + fileNameAbbrev$
		noprogress To PointProcess (periodic, cc): 75, 600
		numPoints = Get number of points
		
		if numPoints <= 0
			@printInfo
		else
			hasPoints = 1
		endif
		
		start_time_sound = Get time from index: 1
		end_time_sound = Get time from index: numPoints
		removeObject: "PointProcess " + fileNameAbbrev$
	
		appendInfoLine: fileNameAbbrev$
		appendInfoLine: start_time_sound
		appendInfoLine: end_time_sound
	
		selectObject: "Sound " + fileNameAbbrev$
		Extract part: start_time_sound, end_time_sound, "rectangular", 1.0, 0
		fileNameAbbrev$ = fileNameAbbrev$ + "_part"
	endif
	
	total_time = Get total duration
	## t is ultimately the midpoint from which F1, F2 is calculated
	t = 0
	
	## find pitch values
	noprogress To Pitch: 0, pitchFloor, pitchCeiling
	pitch = Get mean: 0, 0, "Hertz"
	removeObject: "Pitch " + fileNameAbbrev$
	selectObject: "Sound " + fileNameAbbrev$
	

	### now find F1, F2 values ###
	
	## create a Formant object for later use
	noprogress To Formant (burg): 0, 5, maxForm, formantWindLength, 70
	minusObject: "Formant " + fileNameAbbrev$

	## also create an Intensity object for use
	selectObject: "Sound " + fileNameAbbrev$
	noprogress To Intensity: 100, 0, 1
	selectObject: "Intensity " + fileNameAbbrev$
	max_intensity = Get maximum: 0, 0, "None"

	## depending on letter, process sound file accordingly
	## if syllable is mxl, look for sharpest change in f1 value and move over 0.07 sec to sample f1, f2
	## if syllable is txl, look for sharpest change in intensity value and move over 0.07 sec to sample f1, f2
	## for remaining syllables, divide up sound file into small windows and locate the window with the maximum F1 median
	
	if last_char$ = "l" 
			## counter to go through sound file and calculate derivatives		
			time_counter = 0.1*total_time
			change_in_counter = 0.01
			
		if first_char$ = "m"
			minusObject: "Intensity " + fileNameAbbrev$
			selectObject: "Formant " + fileNameAbbrev$
			index = 1
			# arrays for tracking difference in f1 values, midpoints of time	
			df1[index] = 0 
			t[index] = 0
			max_df1 = 0
		
			## find sharpest change in formant f1 value by collecting differences and times
			while t < total_time and time_counter <= 0.8*total_time
			
				# calculate derivative of f1
				f1a = Get value at time: 1, time_counter, "Hertz", "Linear"
				f1b = Get value at time: 1, time_counter + change_in_counter, "Hertz", "Linear"
				df1[index] = f1b - f1a
				
				# midpoint of derivative selection
				t[index] = (time_counter + time_counter + change_in_counter)/2

				time_counter = time_counter + (change_in_counter)/2
			
				index = index + 1
			endwhile
	
			minusObject: "Formant " + fileNameAbbrev$
			selectObject: "Intensity " + fileNameAbbrev$ 
			for i to index - 1
				mean_intensity = Get mean: t[i] - (change_in_counter)/2, t[i] + (change_in_counter)/2, "dB"
				if (mean_intensity > 0.9*max_intensity and df1[i] != undefined and df1[i] > max_df1)
					t = t[i]
					max_df1 = df1[i]

				endif
			endfor

			#appendInfoLine:"formant method"
		else
			max_int = 0
			
			## find most positive change in intensity
			while time_counter <= 0.8*total_time
				inta = Get value at time: time_counter, "Cubic"
				intb = Get value at time: time_counter + change_in_counter, "Cubic"
				intDiff = intb - inta
				if  inta > 0.9*max_intensity and intb > 0.9*max_intensity and intDiff > max_int
					max_int = intDiff
					t = (time_counter + time_counter + change_in_counter)/2
				endif
				
				time_counter = time_counter + (change_in_counter)/2
			endwhile
			
			#appendInfoLine:"intensity method"
		endif
		
		removeObject: "Intensity " + fileNameAbbrev$
		selectObject: "Formant " + fileNameAbbrev$
		## for txl, mxl pick part of f1 curve after the intensity peak/formant peak
		t = t + 0.07
	else
		windows_in_file = total_time div chooseFWindLength

		## collect intensity values (mean) for set of windows
		## this will be used to determine which time to take F1 values from
		window_mean_intensity[1] = 0
		start_time = 0	
		end_time = chooseFWindLength

		for i to windows_in_file
			window_mean_intensity[i] = Get mean: start_time, end_time, "dB"
			start_time = end_time
			end_time = end_time + chooseFWindLength
		endfor
		removeObject: "Intensity " + fileNameAbbrev$
	
		
		## collect F1, F2 medians for each window
		## find the maximum median F1 
		## (restrictions: f1<1000, intensity value at that time must be high)
		selectObject: "Formant " + fileNameAbbrev$
		start_time = 0
		end_time = chooseFWindLength
		max_median_f1 = 0
		max_median_f2 = 0
		t_alt = 0
		# record second t_alt for F2 values
		
		for i to windows_in_file
			current_median_f1 = Get quantile: 1, start_time, end_time, "Hertz", 0.50
			current_median_f2 = Get quantile: 2, start_time, end_time, "Hertz", 0.50
			current_time = (start_time + end_time) / 2 	
		
			if (current_median_f1 < 1000 and max_median_f1 < current_median_f1 and window_mean_intensity[i] > 0.9*max_intensity)
				max_median_f1 = current_median_f1
				t = current_time
			elif (current_median_f2 > 700 and current_median_f2 < 2500 and max_median_f2 < current_median_f2 and window_mean_intensity[i] > 0.9*max_intensity)
				max_median_f2 = current_median_f2
				t_alt = current_time
			endif
			
			start_time = end_time
			end_time = end_time + chooseFWindLength
		endfor
		
	endif

	## retrieve F1, F2, F3 values as a mean over a 0.07sec-selection
	v1f1 = Get mean: 1, t - 0.035, t + 0.035, "Hertz"
	v1f2 = Get mean: 2, t - 0.035, t + 0.035, "Hertz"
	v1f3 = Get mean: 3, t - 0.035, t + 0.035, "Hertz"

	v1f1_alt = Get mean: 1, t_alt - 0.035, t_alt + 0.035, "Hertz"
	v1f2_alt = Get mean: 1, t_alt - 0.035, t_alt + 0.035, "Hertz"
	v1f3_alt = Get mean: 1, t_alt - 0.035, t_alt + 0.035, "Hertz"

	## output
	## for all sound files except txl, because extraction
	## was performed, time t needs to be readjusted to reflect
	## the original sound file's times
	if not (first_char$ = "t" and last_char$ = "l")
		t = t + start_time_sound
		t_alt = t_alt + start_time_sound			
	endif
		
	@printInfo
	
	
	procedure printError	
		if hasPoints = 1
			fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' 'mid_char$' 'tab$' 't:8' 'tab$'  'v1f1:8' 'tab$'  'v1f2:8' 'tab$'  'v1f3:8' 'tab$' 'pitch:8' 'tab$'  't_alt:8' 'tab$'  'v1f1_alt:8' 'tab$'  'v1f2_alt:8' 'tab$'  'v1f3_alt:8' 'tab$' 'start_time_sound:8' 'tab$' 'end_time_sound:8' 'newline$' 
			#appendInfoLine: fileNameAbbrev$
			#appendInfoLine: "time :" + string$(t-0.035) +  " - " + string$(t+0.035)			#appendInfoLine: v1f1
			#appendInfoLine: v1f2
		else	
			fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' skipped 'newline$'
			endeditor
			select all
			minusObject: strings
			Remove
		endif
	endproc

	endeditor
	
	select all
	minusObject: strings
    Remove
endfor




appendInfoLine: "***Formant analysis complete***"
