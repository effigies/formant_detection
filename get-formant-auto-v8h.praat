##    takes directory of sound files and loops through them
##  calculating the mean f1 and f2 values around the maxima f1 & f2
##

clearinfo

## prompt
form Input Enter directory and output file name
       comment Enter directory where soundfiles are kept:
        sentence directory C:\DATA\FMRI_AUDIO\stimuli_copy\speaker1
        comment Enter directory for output file:
        sentence listDir C:\DATA\FMRI_AUDIO\stimuli_copy\speaker1
        comment Enter name of output file:
        sentence outFile formant-values-auto.txt
    comment Enter window length for standard deviations:
    real stDevWindLength 0.03
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

strings = Create Strings as file list: "list", directory$ + "/*.wav"
numberOfFiles = Get number of strings
writeInfoLine: directory$

fileappend 'listDir$'\'outFile$' 'gender$' - 'listDir$' 'newline$'
fileappend 'listDir$'\'outFile$' File Name 'tab$' time (sec) 'tab$' F1 'tab$' F2 'tab$' F3 'tab$' Pitch 'newline$'

## loops through .wav files and outputs F1, F2 values
for ifile to numberOfFiles

    ## choose sound file for analysis
    selectObject: strings
        fileName$ = Get string: ifile
    fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)
    #dots not allowed in name
    fileNameAbbrev$ = replace$(fileNameAbbrev$, ".", "_", 0)
    Read from file: directory$ + "/" + fileName$

    ## determine syllable being processed based on file name
    word$ = mid$(fileNameAbbrev$, index(fileNameAbbrev$, "_") + 1, 5)
    first_char$ = mid$(word$, 3, 1)
    last_char$ = right$(word$, 1)

    ## convert to PointProcess (pulses) to obtain relevant time area

    selectObject: "Sound " + fileNameAbbrev$
    To PointProcess (periodic, cc): 75, 600
    numPoints = Get number of points
    start_time_sound = Get time from index: 1
    end_time_sound = Get time from index: numPoints
    removeObject: "PointProcess " + fileNameAbbrev$

    appendInfoLine: fileNameAbbrev$
    appendInfoLine: start_time_sound
    appendInfoLine: end_time_sound

    selectObject: "Sound " + fileNameAbbrev$
    Extract part: start_time_sound, end_time_sound, "rectangular", 1.0, 0
    fileNameAbbrev$ = fileNameAbbrev$ + "_part"
    total_time = Get total duration

    #derivative

    counter = 0.1*total_time
    max_df1 = 0
    change_in_counter = 0.01
    index = 1
    df1[index] = 0
    t[index] = 0
    t = 0

    To Intensity: 100, 0, 1
    selectObject: "Intensity " + fileNameAbbrev$
    max_intensity = Get maximum: 0, 0, "None"

    ## depending on letter, process sound file accordingly
    if last_char$ = "l"
        if first_char$ = "l" or first_char$ = "m"
            ## convert sound file to formant
            minusObject: "Intensity " + fileNameAbbrev$
            selectObject: "Sound " + fileNameAbbrev$
            To Formant (burg): 0, 5, maxForm, windLength, 70
            selectObject: "Formant " + fileNameAbbrev$

            ## find sharpest change in formant f1 value by collecting differences and times
            while t < total_time and counter <= 0.8*total_time
                f1a = Get value at time: 1, counter, "Hertz", "Linear"
                f1b = Get value at time: 1, counter + change_in_counter, "Hertz", "Linear"
                df1[index] = f1b - f1a
                #appendInfoLine: "F1 values:"
                #appendInfoLine: f1a
                #appendInfoLine: f1b
                t[index] = (counter + counter + change_in_counter)/2
                counter = counter + (change_in_counter)/2
                index = index + 1
            endwhile

            minusObject: "Formant " + fileNameAbbrev$
            selectObject: "Intensity " + fileNameAbbrev$
            for i to index - 1
                mean_intensity = Get mean: t[i] - (change_in_counter)/2, t[i] + (change_in_counter)/2, "dB"
                if (mean_intensity > 0.9*max_intensity and df1[i] != undefined and df1[i] > max_df1)
                    t = t[i]
                    max_df1 = df1[i]
                    #appendInfoLine: "new max f1"
                    #appendInfoLine: t[i]
                    #appendInfoLine: df1[i]
                endif
            endfor

            removeObject: "Intensity " + fileNameAbbrev$
            selectObject: "Formant " + fileNameAbbrev$
            appendInfoLine:"formant method"
        else
        ## find sharpest change in intensity
            while counter <= 0.8*total_time
                inta = Get value at time: counter, "Cubic"
                intb = Get value at time: counter + change_in_counter, "Cubic"
                df1 = intb - inta
                if  inta > 0.9*max_intensity and intb > 0.9*max_intensity and df1 > max_df1
                    max_df1 = df1
                    t = (counter + counter + change_in_counter)/2
                endif
                counter = counter + (change_in_counter)/2
            endwhile

            removeObject: "Intensity " + fileNameAbbrev$
            selectObject: "Sound " + fileNameAbbrev$
            To Formant (burg): 0, 5, maxForm, windLength, 70
            selectObject: "Formant " + fileNameAbbrev$
            appendInfoLine:"intensity method"
        endif
        t = t + 0.07
    else
        windows_in_file = total_time div stDevWindLength
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
        t = 0

        ## collect F1, F2 means for each window
        for i to windows_in_file
            mean_f1[i] = Get mean: 1, start_time, end_time, "Hertz"
            stdev_time[i] = (start_time + end_time) / 2

            if (mean_f1[i] < 1000 and max_mean_f1 < mean_f1[i] and mean_intensity[i] > 0.9*max_intensity)
                max_mean_f1 = mean_f1[i]
                t = stdev_time[i]
            endif
            start_time = end_time
            end_time = end_time + stDevWindLength
        endfor

    endif



    ## pick part of f1 curve after the intensity peak/formant peak


    ## retrieve F1, F2, F3 values
    v1f1 = Get mean: 1, t - 0.035, t + 0.035, "Hertz"
    v1f2 = Get mean: 2, t - 0.035, t + 0.035, "Hertz"
    v1f3 = Get mean: 3, t - 0.035, t + 0.035, "Hertz"

    ## find pitch
        removeObject: "Formant " + fileNameAbbrev$
        selectObject: "Sound " + fileNameAbbrev$
        To Pitch: 0, pitchFloor, pitchCeiling
        pitch = Get mean: 0, 0, "Hertz"

    ## output
    t = t + start_time_sound

    fileappend 'listDir$'\'outFile$' 'fileNameAbbrev$' 'tab$' 't:8' 'tab$'  'v1f1:8' 'tab$'  'v1f2:8' 'tab$'  'v1f3:8' 'tab$' 'pitch:8' 'newline$'
        appendInfoLine: fileNameAbbrev$
        appendInfoLine: "time :" + string$(t-0.035) +  " - " + string$(t+0.035)
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
    #    .stdev_minimum = arr[1]
    #    for i from 2 to arr_len
    #    if (arr[i] < .stdev_minimum)
    #        .stdev_minimum = arr[i]
    #    endif
    #endfor
    #endproc

