##	takes directory of sound files and loops through them
##  calculating the mean f1 and f2 values around the maxima f1 & f2
##

clearinfo

## prompt
form Input Enter directory and output file name
   	comment Enter directory where soundfiles are kept:
    	sentence directory C:\Users\jgyou\Desktop\stimuli_sample\speaker2
    	comment Enter directory for output file:
    	sentence listDir C:\Users\jgyou\Desktop\stimuli_sample\speaker2
    	comment Enter name of output file:
    	sentence outFile formant-values-auto.txt
	comment Enter window length for standard deviations:
	real stDevWindLength 0.03
	comment Enter maximum formant (male = 5000, female = 5500)
	integer maxForm 5500
	comment Enter window length for formants
	real windLength 0.025
endform

strings = Create Strings as file list: "list", directory$ + "/*.wav"
numberOfFiles = Get number of strings
writeInfoLine: directory$
	
fileappend 'listDir$'\'outFile$' 'newline$'

## loops through .wav files and outputs F1, F2 values
for ifile to numberOfFiles
    
	## choose sound file for analysis
	selectObject: strings
    	fileName$ = Get string: ifile
	fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)
	Read from file: directory$ + "/" + fileName$
	
	## determine number of windows to split sound file into
	selectObject: "Sound " + fileNameAbbrev$
	total_time = Get total duration
	windows_in_file = total_time div stDevWindLength

	##collect intensity values (mean) for set of windows
	To Intensity: 100, 0, 1
	selectObject: "Intensity " + fileNameAbbrev$
	max_intensity = Get maximum: 0, 0, "None"
	mean_intensity[1] = 0	
	start_time = 0
	end_time = stDevWindLength

	for i to windows_in_file
		mean_intensity[i] = Get mean: start_time, end_time, "dB"
		start_time = end_time
		end_time = end_time + stDevWindLength
	endfor
	removeObject: "Intensity " + fileNameAbbrev$

	## convert sound file to formant
	selectObject: "Sound " + fileNameAbbrev$
	To Formant (burg): 0, 5, maxForm, windLength, 70
	selectObject: "Formant " + fileNameAbbrev$
	
	start_time = 0
	end_time = stDevWindLength
	
	max_mean_f1 = 0
	stdev_time[1] = 0
	mean_f1[1] = 0
	stdev_f1[1] = 0
	stdev_f2[1] = 0	
	max_stdev_f1 = 0
	max_stdev_f2 = 0
	
	## collect F1, F2 st deviation values for each window
	for i to windows_in_file
		stdev_f1[i] = Get standard deviation: 1, start_time, end_time, "Hertz"
		stdev_f2[i] = Get standard deviation: 2, start_time, end_time, "Hertz"
		mean_f1[i] = Get mean: 1, start_time, end_time, "Hertz"
		stdev_time[i] = (start_time + end_time) / 2 	
		
		if mean_f1[i] > max_mean_f1
			max_mean_f1 = mean_f1[i]
		elif max_stdev_f1 < stdev_f1[i]
			max_stdev_f1 = stdev_f1[i]
		elif max_stdev_f2 < stdev_f2[i]
			max_stdev_f2 = stdev_f2[i]
		endif

		start_time = end_time
		end_time = end_time + stDevWindLength
	endfor
	
	
	## determine which window to get F1, F2 values from
	stdev_avg_min = 1
	t = 0
	for i to windows_in_file
		stdev_f1[i] = ((stdev_f1[i]/max_stdev_f1) + (stdev_f2[i]/max_stdev_f2)) /2
		## average intensity in window must exceed 90%
		if (stdev_avg_min > stdev_f1[i] and mean_intensity[i] > 0.9*max_intensity and mean_f1[i] > 300)
			appendInfoLine: fileNameAbbrev$
			appendInfoLine: stdev_time[i]
			appendInfoLine: stdev_f1[i]
			appendInfoLine: string$(mean_intensity[i]) + " out of "  + string$(max_intensity)
			stdev_avg_min = stdev_f1[i]
			t = stdev_time[i]
		endif
	endfor
	

	v1f1 = Get mean: 1, t - 0.025, t + 0.025, "Hertz"
	v1f2 = Get mean: 2, t - 0.025, t + 0.025, "Hertz"
	
	
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

	#@findMinimum: windows_in_file
	#writeInfoLine: findMinimum.stdev_minimum

	#procedure findMinimum: arr_len
	#	.stdev_minimum = arr[1]
	#	for i from 2 to arr_len
	#	if (arr[i] < .stdev_minimum)
	#		.stdev_minimum = arr[i]
	#	endif
	#endfor
	#endproc

