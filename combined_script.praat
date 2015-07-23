##    takes directory of sound files and loops through them
##  calculating the mean F1, F2, and F3 values around a user-designated midpoint
##     also outputs vowel, time of midpoint and the average pitch of the file
##

clearinfo
include subprocs.praat

## prompt
form Formant Detection v4: Syllable Repetition Task
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
    boolean automatic 0
    boolean partial 1
    boolean hints 1
    comment Output file name
    text outFile formant-values-cauto.tsv
    comment Enter window length for choosing time of F1 values:
    real chooseFWindLength 0.03
    comment Enter window length for formants
    real formantWindLength 0.025
endform

#
# Choose speakers to run
#
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
    #fileappend 'listDir$'/'outFile$' 'gender$' - 'listDir$' 'newline$'
    fileappend 'listDir$'/'outFile$' File Name'tab$'vowel'tab$'time (sec)'tab$'F1'tab$'F2'tab$'F3'tab$'Pitch'newline$'

    ## loops through .wav files and outputs F1, F2 values
    for ifile to numberOfFiles

        ## choose sound file for analysis
        select strings
        fileName$ = Get string... ifile
        fileNameAbbrev$ = left$(fileName$, length(fileName$) - 4)

        #remove dots that are not allowed in the file name
        fileNameAbbrev$ = replace$(fileNameAbbrev$, ".", "_", 0)
        origFileNameAbbrev$ = fileNameAbbrev$
        Read from file... 'directory$'/'fileName$'

        ## determine syllable being processed based on file name
        word$ = left$(fileNameAbbrev$, 3)
        first_char$ = mid$(word$, 1, 1)
        last_char$ = right$(word$, 1)
        mid_char$ = mid$(word$, 2, 1)

        end_time_sound = Get total duration
        start_time_sound = 0

        if hints
            #
            # Steal estimates from v10
            #
            select Sound 'fileNameAbbrev$'
            noprogress To PointProcess (periodic, cc)... 75 600
            numPoints = Get number of points

            #"noise" files tend to have 0 points
            if numPoints <= 0
                hint = 0
            else
                call extractSound
            endif

            total_time = Get total duration

            if numPoints > 0 and total_time >= (6.4/100)
                call findFormant
                hint = findFormant.t - start_time_sound
                if partial = 0
                    hint = hint + start_time_sound
                    fileNameAbbrev$ = origFileNameAbbrev$
                endif
            elif total_time < (6.4/100)
                hint = 0
            endif
        else
            hint = 0
        endif

        if automatic
            # version 10 equivalent
            if numPoints > 0 and total_time >= (6.4/100)
                fileappend 'listDir$'/'outFile$' 'fileNameAbbrev$''tab$''mid_char$''tab$''findFormant.t:8''tab$''findFormant.v1f1:8''tab$''findFormant.v1f2:8''tab$''findFormant.v1f3:8''tab$''findFormant.pitch:8''newline$'
            else
                call skipSound 'listDir$'/'outFile$' skipped
            endif
        else
            # version 4 equivalent
            select Sound 'fileNameAbbrev$'
            file_duration = Get total duration
            #Extract part: 0.1*file_duration, 0.9*file_duration, "rectangular", 1.0, 1
            View & Edit
            #fileNameAbbrev$ = fileNameAbbrev$ + "_part"

            ## sound editor opens to allow user to choose midpoint of vowel for calculating F1->F3
            editor Sound 'fileNameAbbrev$'
                Formant settings... maxForm 5.0 formantWindLength 30.0 1.0
                if hint <> 0
                    Select... (hint-0.035) (hint+0.035)
                endif
                beginPause ("Choose midpoint of vowel for formant on editor and click Continue")
                    natural ("Number of formants", 5)
                #buttonChosen = endPause ("Continue", "Skip", "Invalid file", 0)
                buttonChosen = endPause ("0.07s Window", "Manual Window", "Ignore", "Mark bad", 0)
                #endPause: "Continue", 0
                t = Get cursor
                sel_start = Get start of selection
                sel_end = Get end of selection
            endeditor

            ## click on Continue to view next sound file
            if buttonChosen = 1 or buttonChosen == 2

                ## calculates F1, F2, F3
                To Formant (burg)... 0 number_of_formants maxForm formantWindLength 70
                select Formant 'fileNameAbbrev$'

                if buttonChosen = 1
                    win_start = t - 0.035
                    win_end = t + 0.035
                else
                    win_start = sel_start
                    win_end = sel_end
                endif

                v1f1 = Get mean... 1 win_start win_end Hertz
                v1f2 = Get mean... 2 win_start win_end Hertz
                v1f3 = Get mean... 3 win_start win_end Hertz

                ## find pitch
                select Formant 'fileNameAbbrev$'
                Remove
                select Sound 'fileNameAbbrev$'
                To Pitch... 0 pitchFloor pitchCeiling
                pitch = Get mean... 0 0 Hertz

                t = t + start_time_sound
                ## output results
                fileappend 'listDir$'/'outFile$' 'fileNameAbbrev$' 'tab$' 'mid_char$' 'tab$' 't:8' 'tab$' 'v1f1:8' 'tab$' 'v1f2:8' 'tab$' 'v1f3:8' 'tab$' 'pitch:8' 'newline$'

            elif buttonChosen = 3
                #call skipSound 'listDir$'/'outFile$' 'mid_char$''tab$'Skipped or separately checked
            else
                ## allows for skipping files
                ## skip option available for empty sound files/other scenarios
                call skipSound 'listDir$'/'outFile$' 'mid_char$''tab$'Invalid file
            endif
        endif

        select all
        minus strings
        Remove
    endfor

    select strings
    Remove
endproc

printline "***Formant analysis complete***"

