##	takes directory of sound files and loops through them
##  calculating the mean f1 and f2 values around the maxima f1 & f2
##

clearinfo

form Input Enter directory and output file name
   	comment Enter directory where soundfiles are kept:
    	sentence directory C:\Users\jgyou\Desktop\stimuli_sample\speaker2
    	comment Enter directory for output file:
    	sentence listDir C:\Users\jgyou\Desktop\stimuli_sample\speaker2
    	comment Enter name of output file:
    	sentence outFile formant-values-auto.txt
	comment Enter window length for standard deviations:
	real stDevWindLength 0.04
	comment Enter maximum formant (male = 5000, female = 5500)
	integer maxForm 5500
	comment Enter window length for formants
	real windLength 0.025
endform

strings = Create Strings as file list: "list", directory$ + "/*.wav"
numberOfFiles = Get number of strings
writeInfoLine: directory$


## loops through .wav files and outputs F1, F2 values
for ifile to numberOfFiles
    
	## choose sound file for analysis
	selectObject: strings
    	fileName$ = Get string: ifile
	fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)
	Read from file: directory$ + "/" + fileName$
	
	## go through entire file and look at chunks of the file
	selectObject: "Sound " + fileNameAbbrev$
	total_time = Get total duration
	windows_in_file = total_time div stDevWindLength
	To Formant (burg): 0, 5, maxForm, windLength, 70
	selectObject: "Formant " + fileNameAbbrev$
	
	start_time = 0
	end_time = 0.04
	stdev_max_f1 = 0
	stdev_max_f2 = 0
	stdev_max_f3 = 0
	stdev_time[1] = 0
	stdev_f1[1] = 0
	stdev_f2[1] = 0	
	stdev_f3[1] = 0
	
	## locate smallest st dev of window
	for i to windows_in_file
		local_stdev_f1 = Get standard deviation: 1, start_time, end_time, "Hertz"
		local_stdev_f2 = Get standard deviation: 2, start_time, end_time, "Hertz"
		local_stdev_f3 = Get standard deviation: 3, start_time, end_time, "Hertz"
			# global stdev max for comparison purposes
			if stdev_max_f1 < local_stdev_f1
				stdev_max_f1 = local_stdev_f1
				appendInfoLine: "ST DEV F1 " + fileNameAbbrev$
				appendInfoLine: local_stdev_f1
				appendInfoLine: start_time
			elif stdev_max_f2 < local_stdev_f2
				stdev_max_f2 = local_stdev_f2
				appendInfoLine: "ST DEV F2 " + fileNameAbbrev$
				appendInfoLine: local_stdev_f2
				appendInfoLine: start_time
			elif stdev_max_f3 < local_stdev_f3
				stdev_max_f3 = local_stdev_f3
				appendInfoLine: "ST DEV F3 " + fileNameAbbrev$
				appendInfoLine: local_stdev_f3
				appendInfoLine: start_time
			endif

			
			# update arrays
			stdev_f1[i] = local_stdev_f1
			stdev_f2[i] = local_stdev_f2
			stdev_f3[i] = local_stdev_f3
			stdev_time[i] = (start_time + end_time) / 2

		start_time = end_time
		end_time = end_time + stDevWindLength
	endfor
		
	## check F1 & F2
	stdev_avg_min = 1
	t = 0
	for i to windows_in_file
		stdev_f1[i] = ((stdev_f2[i] / stdev_max_f2) +  (stdev_f1[i] / stdev_max_f1) + (stdev_f3[i] / stdev_max_f3)) / 3
		if (stdev_avg_min > stdev_f1[i])
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

