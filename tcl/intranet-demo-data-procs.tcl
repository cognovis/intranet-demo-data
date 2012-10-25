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
    if {"" == $start_date} { set start_date "2012-01-01" }
    set end_date [db_string max_days "select :start_date::date + :max_days::integer from dual"]

    set day_list [db_list days_list "select day.day from im_day_enumerator(:start_date, :end_date) day"]
    foreach day $day_list {

	# Set the global parameter for other packages to evaluate to the curent day
	parameter::set_from_package_key -package_key "intranet-demo-data" -parameter "DemoDataDay" -value $day

	# calculate day as integer
	set day_julian [im_date_ansi_to_julian $day]
	# Weekday starts with 0=sunday and ends with 6=saturday
	set day_of_week [expr ($day_julian + 1) % 7]

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
	set target_company_load_potential_or_open [expr $capacity_perc * 120]
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

	    ns_log Notice "im_demo_data_main_loop: im_demo_data_risk_create -project_id $project_id"
	    im_demo_data_risk_create -day $day -project_id $project_id

	}

	# Create weekly project reports
	set main_projects [db_list main_projects "
		select	p.project_id
		from	im_projects p
		where	p.parent_id is null and
			p.project_status_id in (select * from im_sub_categories([im_project_status_open]))
	"]
	foreach project_id $main_projects {
	    # Create a weekly project status report on Thursday
	    if {4 == $day_of_week} {
		ns_log Notice "im_demo_data_main_loop: im_demo_data_status_report -project_id $project_id"
		im_demo_data_status_report_create -day $day -project_id $project_id
	    }
	}

	# Log hours for all employees
	ns_log Notice "im_demo_data_main_loop: im_demo_data_timesheet_log_employee_hours"
	im_demo_data_timesheet_log_employee_hours -day $day

	# Add payments for invoices
	ns_log Notice "im_demo_data_main_loop: im_demo_data_pay_invoices -day $day"
	im_demo_data_pay_invoices -day $day


	# Patch costs objects
	db_dml patch_costs "update im_costs set effective_date = :day where cost_id > :prev_object_id"
	db_dml patch_objects "update acs_objects set creation_date = :day where object_id > :prev_object_id"
	
	# Move all audit records back to the specified day
	set end_audit_tz [db_string end_audit_tz "select now() from dual" -default 0]
	db_dml shift_audits "update im_audits set audit_date = :day where audit_id > :prev_audit_id"
	db_dml shift_project_audits "update im_projects_audit set last_modified = :day where audit_id > :prev_audit_id"

	# Write indicator results
	im_indicator_evaluation_sweeper -day $day
	# Cleanup indicator results later then today. These can't be correct...
	db_dml del_indicator_results "delete from im_indicator_results where result_date::date > :day::date"

	ns_log Notice "im_demo_data_main_loop: End"
    }
}


