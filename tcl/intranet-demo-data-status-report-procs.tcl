# packages/intranet-demo-data/tcl/intranet-demo-data-status-report-procs.tcl
ad_library {

    Status-Report support
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date 2012-10-06
    
    @vss $Workfile: intranet-dynfield-procs.tcl $ $Revision$ $Date$
}




ad_proc -public im_demo_data_status_report_duplicate_green_choices {
    options
} {
    Takes a list of id-choice_text tuples and:
    Return a list of id-choice_text tuples.
    Tuples with the choice_text "green" will be multiplied, 
    so that green will predominate when a random element
    is picked later.
} {
    set result [list]
    foreach tuple $options {
	set text [lindex $tuple 1]
	switch [string tolower $text] {
	    green {
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
	    }
	    yellow {
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
		lappend result $tuple
	    }
	    default {
		lappend result $tuple
	    }
	}
    }
    return $result
}


ad_proc -public im_demo_data_status_report_create {
    { -day ""}
    { -current_user_id "" }
    -project_id:required
} {
    Add a few random status-reports to a project
} {
    if {"" == $day} { set day [db_string now "select now()::date from dual"] }
    if {"" == $current_user_id} { set current_user_id [ad_get_user_id] }

    # Get the ID of the preconfigured survey
    set survey_id [db_string survey "select min(survey_id) from survsimp_surveys where name = 'Project Manager Weekly Report' or name = 'Project Status Report'" -default ""]
    if {"" == $survey_id} { 
	ns_log Error "im_demo_data_status_report_create: Didn't find a survey 'Project Manager Weekly Report' or 'Project Status Report'."
	return "" 
    }

    set project_task_names [db_list project_task_names "
 	select	p.project_name
	from	im_projects p,
		im_projects main_p
	where	main_p.project_id = :project_id and
		p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
    "]

    # Create a new response (= grouping of multiple answers)
    set response_id [db_string new_response "
	select survsimp_response__new (
		null,
		:survey_id,
		null,
		'f',
		:current_user_id,
		'[ns_conn peeraddr]',
		:survey_id
	    )
    "]

    # Associate the response with the project
    db_dml update_response "
	update survsimp_responses set
		related_object_id = :project_id
	where	response_id = :response_id
    "

    # Get the list of all questions
    set survey_questions [db_list_of_lists survey_questions "
	select	question_id, 
		question_text, 
		abstract_data_type, 
		presentation_type
	from	survsimp_questions
	where	survey_id = :survey_id
		and active_p = 't'
	order by sort_key
    "]

    foreach question $survey_questions {
        set question_id [lindex $question 0]
        set question_text [lindex $question 1]
        set abstract_data_type [lindex $question 2]
        set presentation_type [lindex $question 3]

	switch $abstract_data_type {
	    choice {
		# Determine a random choice of green, yellow or red.
		set options [util_memoize [list db_list_of_lists choices "select choice_id, label from survsimp_question_choices where question_id = $question_id"]]
		set options [im_demo_data_status_report_duplicate_green_choices $options]
		set option [util::random_list_element $options]
		set choice_id [lindex $option 0]
		# Insert the choice into the response
		db_dml insert "insert into survsimp_question_responses (response_id, question_id, choice_id) values (:response_id, :question_id, :choice_id)"
	    }
	    text {
		# Create a random reply based on the tasks of the project
		set text ""
		set cnt [expr int(1 + rand() * 4)]
		for {set i 0} {$i < $cnt} {incr i} {
		   append text "- [util::random_list_element $project_task_names]\n"
		}
		db_dml insert "insert into survsimp_question_responses (response_id, question_id, clob_answer) values (:response_id, :question_id, :text)"
	    }
	}    
    
    }        
}
