# packages/intranet-demo-data/tcl/intranet-demo-data-procs.tcl
ad_library {

    Main Loop for demo-data generation
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date 2012-10-06
    
    @vss $Workfile: intranet-dynfield-procs.tcl $ $Revision$ $Date$
}


ad_proc im_demo_data_main_loop {
    {-start_date ""}
    {-max_days "1"}
} {
    Run the company simulation for a number of days
} {
    if {"" == $start_date} {  set start_date [db_string start_date "select max(day)::date + 1 from im_hours" -default ""] }
    if {"" == $start_date} { set start_date "2010-01-01" }
    set end_date [db_string max_days "select :start_date::date + :max_days::integer from dual"]

    set day_list [db_list days_list "select day.day from im_day_enumerator(:start_date, :end_date) day"]
    foreach day $day_list {

	ns_log Notice "im_demo_data_main_loop: "
	ns_log Notice "im_demo_data_main_loop: "
	ns_log Notice "im_demo_data_main_loop: "
	ns_log Notice "im_demo_data_main_loop: "
	ns_log Notice "im_demo_data_main_loop: Start"
	# Fake the creation_date of cost objects and audit information
	# Therefore store the information about the last objects
	set prev_object_id [db_string prev_object_id "select max(cost_id) from im_costs"]
	set prev_audit_id [db_string prev_audit "select last_value from im_audit_seq"]

        # ToDo: Get the company load of the next 100 days and
	# compare with the company capacity (number of employees x availability)
	set company_load_potential_or_open [im_demo_data_timesheet_company_load -start_date $day]
	set company_load_open [im_demo_data_timesheet_company_load -start_date $day -project_status_id [im_project_status_open]]
	set capacity_perc [im_demo_data_timesheet_company_capacity_percentage]
	set target_company_load_potential_or_open [expr $capacity_perc * 150]
	set target_company_load_open [expr $capacity_perc * 30]

        # Create new projects if not enough work load
	ns_log Notice "im_demo_data_main_loop: company_load_pot_or_open=$company_load_potential_or_open < target_company_load_pot_or_open=$target_company_load_potential_or_open"
	if {$company_load_potential_or_open < $target_company_load_potential_or_open} {
	    ns_log Notice "im_demo_data_main_loop: im_demo_data_project_new_from_template"
	    im_demo_data_project_new_from_template -day $day
	}

	# Advance the sales pipeline if there are not enough open projects
	ns_log Notice "im_demo_data_main_loop: company_load_open=$company_load_open < target_company_load_open=$target_company_load_open"
	if {$company_load_open < $target_company_load_open} {
	    ns_log Notice "im_demo_data_main_loop: im_demo_data_project_sales_pipeline_advance"
	    im_demo_data_project_sales_pipeline_advance -day $day
	}

	# Staff the project if it is in status "open" but has unassigned skill profiles
	set projects_to_staff [db_list projects_to_staff "
		select	p.project_id
		from	im_projects p
		where	p.parent_id is null and
			p.project_status_id in (select * from im_sub_categories([im_project_status_open])) and
			p.project_lead_id is null
	"]
	foreach project_id $projects_to_staff {
	    ns_log Notice "im_demo_data_main_loop: im_demo_data_project_staff -project_id $project_id"
	    im_demo_data_project_staff -day $day -project_id $project_id

	    ns_log Notice "im_demo_data_main_loop: im_demo_data_project_risk_create -project_id $project_id"
	    im_demo_data_project_risk_create -day $day -project_id $project_id

	}

	# Log hours for all employees
	ns_log Notice "im_demo_data_main_loop: im_demo_data_timesheet_log_employee_hours"
	im_demo_data_timesheet_log_employee_hours -day $day

	# ToDo: Write invoices for "Delivered" projects

	# Patch costs objects
	db_dml patch_costs "update im_costs set effective_date = :day where cost_id > :prev_object_id"
	db_dml patch_objects "update acs_objects set creation_date = :day where object_id > :prev_object_id"
	
	# Move all audit records back to the specified day
	set end_audit_tz [db_string end_audit_tz "select now() from dual" -default 0]
	db_dml shift_audits "update im_audits set audit_date = :day where audit_id > :prev_audit_id"
	db_dml shift_project_audits "update im_projects_audit set last_modified = :day where audit_id > :prev_audit_id"
	ns_log Notice "im_demo_data_main_loop: End"
    }
}




ad_proc im_demo_data_risk_create {
    { -day ""}
    -project_id:required
} {
    Add a few random risks to a project
} {
    if {"" == $day} { set day "2012-01-01" }
    set project_hours [im_demo_data_timesheet_work_hours -project_id $project_id]
    set risk_user_id [db_string pm "select project_lead_id from im_projects where project_id = :project_id" -default [ad_get_user_id]]

    # Assume and average cost per hour of EUR/USD 50/h
    set project_cost [expr $project_hours * 50.0]

    set risks {
	{
	    "Loss to project of key staff" 
	    "low" "high" 
	    "Unable to complete key tasks" 
	    "Emphasise importance of project within organization."
	    "Reports of absence, or diversion of staff to other work."
	    "Identify alternative resources in case of unexpected absence."
	} {
	    "Significant changes in user requirements" 
	    "low" "high" 
	    "Time-quality-cost"
	    "Ensure that the user requirements are fully agreed before specification."
	    "Request for changes to agreed specification."
	    "Discuss impact of change on schedules or design, and agree if change to specification will proceed. Implement project change, if agreed."
	} {
	    "Major changes to organization structure"
	    "low" "high" 
	    "Changes to system, processes, training, rollout"
	    "None"
	    "Information from senior staff."
	    "Make sure management are aware of need for user input from people with different responsibilities"
	} {
	    "Volume of change requests following testing extending work on each phase"
	    "high" "high" 
	    "Delays"
	    "Agree specification. Agree priorities. Reasonable\
 consultation on format"
	    "Swamped with changes. Delay in signing off items"
	    "Managerial decision on importance, technically feasibility and observance of time constraints"
	} {
	    "Changes in priorities of senior management"
	    "med" "high" 
	    "Removal of resource, lack of commitment, change in strategy or closure of project"
	    "Make sure that senior management are aware of the project, its relative importance, and its progress"
	    "Announcements in University publications, meetings etc."
	    "Inform senior management of the knock on effects of their decisions."
	} {
	    "Lack of organizational or departmental buy-in"
	    "high" "high" 
	    "Failure to achieve business benefits. Ineffective work practices. More fragmented processes. Poor Communication"
	    "Ensure User Requirements are properly assessed. Executive leadership and ongoing involvement. Communications and planning focus. Appoint Comms Manager"
	    "Staff Survey, Benefits realisation monitoring"
	    "Review deliverables"
	} {
	    "Lack of commitment or ability to change current business processes"
	    "high" "medium"
	    "Failure to achieve business benefits. Extended duration. Scope creep to copy today's processes."
	    "Requires additional business process analyst resource."
	    "Lack of commitment to reviewing and challenging existing processes early in the project."
	    "Attempt to engage users depts. Involve senior management."
	}
    }

    foreach risk $risks {
	set risk_name [lindex $risk 0]
	set risk_probability_level [lindex $risk 1]
	set risk_impact_level [lindex $risk 2]
	set risk_effect_on_project [lindex $risk 3]
	set risk_mitigation_actions [lindex $risk 4]
	set risk_triggers [lindex $risk 5]
	set risk_actions [lindex $risk 6]

	switch $risk_probability_level {
	    low { set risk_probability [expr rand() * 30.0] }
	    med { set risk_probability [expr 30.0 + rand() * 40.0] }
	    high { set risk_probability [expr 70.0 + rand() * 30.0] }
	    default { set risk_probability [expr rand() * 100.0] }
	}
	set risk_probability [expr round($risk_probability / 100.0) * 100]

	switch $risk_impact_level {
	    low { set risk_impact [expr 100 + $project_cost * (rand() * 0.10)] }
	    med { set risk_impact [expr $project_cost * (0.10 + rand() * 0.10)] }
	    high { set risk_impact [expr $project_cost * (0.20 + rand() * 0.10)] }
	    default { set risk_impact [expr $project_cost * (rand() * 0.3)] }
	}
	set risk_impact [expr round($risk_impact / 100.0) * 100]

	set risk_status_id 75000
	set risk_type_id 75100
	set risk_id [db_string new_risk "select im_risk__new (
		-- Default 6 parameters that go into the acs_objects table
		null,			-- risk_id  default null
		'im_risk',		-- object_type default im_risk
		:day,			-- creation_date default now()
		:risk_user_id,		-- creation_user default null
		'0.0.0.0',		-- creation_ip default null
		null,			-- context_id default null

		-- Specific parameters with data to go into the im_risks table
		:project_id,	       	-- project container
		:risk_status_id,	-- active or inactive or for WF stages
		:risk_type_id,		-- user defined type of risk. Determines WF.
		:risk_name		-- Unique name of risk per project
	)"]

	db_dml update_risk "
		update im_risks set
			risk_probability_percent = :risk_probability,
			risk_impact = :risk_impact
		where risk_id = :risk_id
	"
    }
}
