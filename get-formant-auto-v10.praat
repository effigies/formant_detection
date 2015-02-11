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

clearinfo
include subprocs.praat

## prompt
form Formant Detection v10: Syllable Repetition Task
    comment Enter base sound file directory
    text baseDirectory /share/qnl2/fMRI/syllable_repetition/formants.new/sound_files
    comment Enter metadata directory
    text metadataDirectory /share/qnl-linux1/fs_sess_metadata
    choice speaker: 2
        button All Speakers
        button All Subjects
        button All Stimuli
        button Stimulus 1 (F)
        button Stimulus 2 (M)
        button Stimulus 3 (F)
        button Stimulus 4 (M)
        button Subject 01 (M)
        button Subject 02 (F)
        #button Subject 03 (F)
        #button Subject 04 (F)
        button Subject 05 (M)
        button Subject 06 (F)
        button Subject 07 (F)
        button Subject 08 (M)
        button Subject 09 (F)
        button Subject 10 (F)
        button Subject 11 (M)
        button Subject 12 (F)
        button Subject 13 (F)
        button Subject 14 (M)
        button Subject 15 (M)
        button Subject 16 (F)
        button Subject 17 (F)
    comment Output file name
    text outFile formant-values-auto-v10.tsv
    comment Enter window length for choosing time of F1 values:
    real chooseFWindLength 0.03
    comment Enter window length for formants
    real formantWindLength 0.025
endform

if (speaker$ = "All Stimuli") or (speaker$ = "All Speakers")
    for i from 1 to 4
        if i mod 2 = 1
            call runSpeaker Stimulus 'i' (F)
        else
            call runSpeaker Stimulus 'i' (M)
        endif
    endfor
endif

if (speaker$ = "All Speakers") or (speaker$ = "All Subjects")
    call runSpeaker Subject 01 (M)
    call runSpeaker Subject 02 (F)

    for i from 5 to 9
        if i = 5 or i = 8
            call runSpeaker Subject 0'i' (M)
        else
            call runSpeaker Subject 0'i' (F)
        endif
    endfor
    for i from 10 to 17
        if i = 11 or i = 14 or i = 15
            call runSpeaker Subject 'i' (M)
        else
            call runSpeaker Subject 'i' (F)
        endif
    endfor
endif

if mid$ (speaker$, 1) = "S"
    call runSpeaker 'speaker$'
endif

procedure runSpeaker speakerx$
    ## gender-dependent variables
    maxForm = 0
    pitchFloor = 0
    pitchCeiling = 0
    numberOfFormants = 5

    gender$ = mid$ (speakerx$, 13)

    if gender$ = "M"
        maxForm = 5000
        pitchFloor = 75
        pitchCeiling = 300
    elif gender$ = "F"
        maxForm = 5500
        pitchFloor = 100
        pitchCeiling = 500
    endif

    id$ = extractWord$ (speakerx$, " ")
    if startsWith (speakerx$, "Stimulus")
        directory$ = baseDirectory$ + "/stimuli_processed/speaker" + id$
        listDir$ = directory$
    else
        directory$ = baseDirectory$ + "/recordings/NWR_0" + id$ + "/parsed"
        listDir$ = metadataDirectory$ + "/SR" + id$ + "stc"
    endif

    ## retrieve file list

    strings = Create Strings as file list... list 'directory$'/*.wav
    numberOfFiles = Get number of strings
    echo 'directory$'

    ## header for file
    fileappend 'listDir$'/'outFile$' 'gender$' - 'listDir$' 'newline$'
    fileappend 'listDir$'/'outFile$' File Name 'tab$' vowel'tab$' time (sec) 'tab$' F1 'tab$' F2 'tab$' F3 'tab$' Pitch 'newline$'

    ## loops through .wav files and outputs F1, F2 values
    for ifile to numberOfFiles

        ## choose sound file for analysis
        select strings
        fileName$ = Get string... ifile
        fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)

        #remove dots that are not allowed in the file name
        fileNameAbbrev$ = replace$(fileNameAbbrev$, ".", "_", 0)
        Read from file... 'directory$'/'fileName$'

        ## determine syllable being processed based on file name
        word$ = left$(fileNameAbbrev$, 3)
        #word$ = mid$(fileNameAbbrev$, 12, 3)
        first_char$ = mid$(word$, 1, 1)
        last_char$ = right$(word$, 1)
        mid_char$ = mid$(word$, 2, 1)



        end_time_sound = Get total duration
        start_time_sound = 0

        # for txl, because intensity slopes down in the vowel, this has to be processed differently
        # sound cannot be extracted for txl

        ## convert Sound to PointProcess (pulses) to obtain relevant time area in file to focus on
        #if not (first_char$ = 't' and last_char$ = 'l')
            select Sound 'fileNameAbbrev$'
            noprogress To PointProcess (periodic, cc)... 75 600
            numPoints = Get number of points

            #"noise" files tend to have 0 points
            if numPoints <= 0
                call skipSound 'listDir$'/'outFile$' skipped
            else
                call extractSound
            endif

        #endif

        total_time = Get total duration

        if numPoints > 0 and total_time >= (6.4/100)
            call findFormant
        elif total_time < (6.4/100)
            call skipSound 'listDir$'/'outFile$' skipped
        endif


        endeditor

        select all
        minus strings
        Remove
    endfor
    select strings
    Remove

    printline "***Formant analysis complete***"
endproc
