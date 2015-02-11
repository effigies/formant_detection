#!/usr/bin/praat
##    takes directory of sound files and loops through them to calculate F1, F2, F3, and pitch
##
##
##  for remaining syllable types:
##     finding the section of the sound file with the highest median f1 value
##     and using that time point as the midpoint from which to calculate F1,
##    F2, and F3 over a 0.07 sec interval
##
##    in all cases, pitch is an average calculated over entire sound file

# no information will be provided for skipped files
procedure skipSound fname$ skipMsg$
    fileappend 'fname$' 'fileNameAbbrev$' 'tab$' 'skipMsg$' 'newline$'
endproc

procedure extractSound
    start_time_sound = Get time from index... 1
    end_time_sound = Get time from index... numPoints
    Remove


    if first_char$ = "t" and last_char$ = "l"
        start_time_sound = start_time_sound - 0.07
    endif
    printline 'fileNameAbbrev$'
    printline 'start_time_sound'
    printline 'end_time_sound'

    select Sound 'fileNameAbbrev$'
    Extract part... start_time_sound end_time_sound rectangular 1.0 0
    fileNameAbbrev$ = fileNameAbbrev$ + "_part"
endproc

procedure findFormant

    ## t is ultimately the midpoint from which F1, F2 is calculated
    t = 0

    ## find pitch values
    noprogress To Pitch... 0 pitchFloor pitchCeiling
    pitch = Get mean... 0 0 Hertz
    select Pitch 'fileNameAbbrev$'
    Remove
    select Sound 'fileNameAbbrev$'


    ### now find F1, F2 values ###

    ## create a Formant object for later use
    noprogress To Formant (burg)... 0 numberOfFormants maxForm formantWindLength 70
    minus Formant 'fileNameAbbrev$'

    ## also create an Intensity object for use
    select Sound 'fileNameAbbrev$'
    noprogress To Intensity... 100 0 1
    select Intensity 'fileNameAbbrev$'
    max_intensity = Get maximum... 0 0 None

    ## depending on letter, process sound file accordingly
    ## if syllable is mxl, look for sharpest change in f1 value and move over 0.07 sec to sample f1, f2
    ## if syllable is txl, look for sharpest change in intensity value and move over 0.07 sec to sample f1, f2
    ## for remaining syllables, divide up sound file into small windows and locate the window with the maximum F1 median

    if last_char$ = "l"
            ## counter to go through sound file and calculate derivatives
            time_counter = 0.1*total_time
            change_in_counter = 0.01

        if first_char$ = "m"
            call useF1Deriv
        else
            call useIntensityDeriv
        endif

        select Intensity 'fileNameAbbrev$'
        Remove
        select Formant 'fileNameAbbrev$'
        ## for txl, mxl pick part of f1 curve after the intensity peak/formant peak
        t = t + 0.07
    else
        call useF1Median
    endif

    ## retrieve F1, F2, F3 values as a mean over a 0.07sec-selection
    v1f1 = Get mean... 1 (t-0.035) (t+0.035) Hertz
    v1f2 = Get mean... 2 (t-0.035) (t+0.035) Hertz
    v1f3 = Get mean... 3 (t-0.035) (t+0.035) Hertz

    ## output
    ## for all sound files except txl, because extraction
    ## was performed, time t needs to be readjusted to reflect
    ## the original sound file's times
    #if not (first_char$ = "t" and last_char$ = "l")
        t = t + start_time_sound

    #endif


    fileappend 'listDir$'/'outFile$' 'fileNameAbbrev$' 'tab$' 'mid_char$' 'tab$' 't:8' 'tab$'  'v1f1:8' 'tab$'  'v1f2:8' 'tab$'  'v1f3:8' 'tab$' 'pitch:8' 'newline$'
    #appendInfoLine: fileNameAbbrev$
    #appendInfoLine: "time :" + string$(t-0.035) +  " - " + string$(t+0.035)            #appendInfoLine: v1f1
    #appendInfoLine: v1f2

endproc


## if syllable is mxl, look for sharpest change in f1 value and move over 0.07 sec to sample f1, f2
procedure useF1Deriv
    minus Intensity 'fileNameAbbrev$'
    select Formant 'fileNameAbbrev$'
    index = 1
    # arrays for tracking difference in f1 values, midpoints of time
    df1[index] = 0
    t[index] = 0
    max_df1 = 0

    ## find sharpest change in formant f1 value by collecting differences and times
    while t < total_time and time_counter <= 0.8*total_time

        # calculate derivative of f1
        f1a = Get value at time... 1 time_counter Hertz Linear
        f1b = Get value at time... 1 (time_counter+change_in_counter) Hertz Linear
        df1[index] = f1b - f1a

        # midpoint of derivative selection
        t[index] = (time_counter + time_counter + change_in_counter)/2
        time_counter = time_counter + (change_in_counter)/2
        index = index + 1
    endwhile

    minus Formant 'fileNameAbbrev$'
    select Intensity 'fileNameAbbrev$'
    for i to index - 1
        mean_intensity = Get mean... (t[i]-(change_in_counter)/2) (t[i]+(change_in_counter)/2) dB
        if (mean_intensity > 0.9*max_intensity and df1[i] <> undefined and df1[i] > max_df1)
            t = t[i]
            max_df1 = df1[i]
        endif
    endfor

    #appendInfoLine:"formant method"
endproc


## if syllable is txl, look for sharpest change in intensity value and move over 0.07 sec to sample f1, f2
procedure useIntensityDeriv
    max_int = 0

    ## find most positive change in intensity
    while time_counter <= 0.8*total_time
        inta = Get value at time... time_counter Cubic
        intb = Get value at time... (time_counter+change_in_counter) Cubic
        intDiff = intb - inta
        if  inta > 0.9*max_intensity and intb > 0.9*max_intensity and intDiff > max_int
            max_int = intDiff
            t = (time_counter+time_counter+change_in_counter)/2
        endif

        time_counter = time_counter + change_in_counter/2
    endwhile

    #appendInfoLine:"intensity method"
endproc


## for remaining syllables, divide up sound file into small windows and locate the window with the maximum F1 median
procedure useF1Median
    windows_in_file = total_time div chooseFWindLength

    ## collect intensity values (mean) for set of windows
    ## this will be used to determine which time to take F1 values from
    window_mean_intensity[1] = 0
    start_time = 0
    end_time = chooseFWindLength

    for i to windows_in_file
        window_mean_intensity[i] = Get mean... start_time end_time dB
        start_time = end_time
        end_time = end_time + chooseFWindLength
    endfor
    select Intensity 'fileNameAbbrev$'
    Remove


    ## collect F1, F2 medians for each window
    ## find the maximum median F1
    ## (restrictions: f1<1000, intensity value at that time must be high)
    select Formant 'fileNameAbbrev$'
    start_time = 0
    end_time = chooseFWindLength
    max_median_f1 = 0
    max_median_f2 = 0
    t_alt = 0
    # record second t_alt for F2 values

    for i to windows_in_file
        current_median_f1 = Get quantile... 1 start_time end_time Hertz 0.50
        current_median_f2 = Get quantile... 2 start_time end_time Hertz 0.50
        current_time = (start_time + end_time) / 2

        if (current_median_f1 < 1000 and max_median_f1 < current_median_f1 and window_mean_intensity[i] > 0.9*max_intensity)
            max_median_f1 = current_median_f1
            t = current_time
        elif (current_median_f2 > 700 and current_median_f2 < 2500 and max_median_f2 < current_median_f2 and window_mean_intensity[i] > 0.9*max_intensity)
            max_median_f2 = current_median_f2
        endif

        start_time = end_time
        end_time = end_time + chooseFWindLength
    endfor
endproc
