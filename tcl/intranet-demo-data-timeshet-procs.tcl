# packages/intranet-demo-data/tcl/intranet-demo-data-procs.tcl
ad_library {

    Support for Timesheet Logging
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date 2012-05-06
    
    @vss $Workfile: intranet-dynfield-procs.tcl $ $Revision$ $Date$
}



ad_proc im_demo_data_timesheet_work_hours {
    -project_id:required
} {
    Returns the accumulated estimated_hours of a project.
} {
    return [util_memoize [list im_demo_data_timesheet_work_hours_helper -project_id $project_id]]
}

ad_proc im_demo_data_timesheet_work_hours_helper {
    -project_id:required
} {
    Returns the accumulated estimated_hours of a project.
} {
    set work_hours_sql "
	select	sum(planned_units * uom_factor) from (
	select	t.planned_units,
		CASE WHEN t.uom_id = 321 THEN 8.0 ELSE 1.0 END as uom_factor
	from	im_projects main_p,
		im_projects sub_p,
		im_timesheet_tasks t
	where	main_p.project_id = :project_id and
		sub_p.project_id = t.task_id and
		sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
	) t
    "

    return [db_string estimated_hours $work_hours_sql]
}


ad_proc im_demo_data_timesheet_company_load {
    { -start_date ""}
    { -end_date ""}
} {
    Calculates the average work load for the entire company in the 
    specified date interval. These values are used later to calculate
    where to place new projects.
} {
    if {"" == $start_date} { set start_date [db_string start_date "select now()::date from dual"] }
    if {"" == $end_date} { set end_date [db_string end_date "select now()::date + 100 from dual"] }

    # -----------------------------------------------------
    # Check the average work load for the next days

    set workload_sql "
	select	coalesce(sum(estimated_days), 0.0) as project_work
	from	(select	main_p.project_id,
			main_p.project_nr,
			main_p.project_name,
			(select	coalesce(sum(t.planned_units * t.uom_factor * (100.0 - t.percent_completed)), 0.0) / 8.0 from (
				select	t.planned_units,
					sub_p.percent_completed,
					CASE WHEN t.uom_id = 321 THEN 8.0 ELSE 1.0 END as uom_factor
				from	im_projects sub_p,
					im_timesheet_tasks t
				where	sub_p.project_id = t.task_id and
					sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
			) t) as estimated_days
		from	im_projects main_p
		where	main_p.parent_id is null and
			main_p.project_status_id in (select * from im_sub_categories(76)) and
			main_p.end_date > :start_date
		) open_tasks
    "

    return [db_string workload $workload_sql]
}

ad_proc im_demo_data_timesheet_company_capacity_percentage {
} {
    Calculates the available percentage of users.
} {
    set capacity_sql "
	select	sum(coalesce(e.availability,0))
	from	cc_users u,
		im_employees e
	where	u.user_id = e.employee_id
    "

    return [db_string capacity $capacity_sql]
}



ad_proc im_demo_data_timesheet_log_employee_hours {
    {-day ""}
} {
    Checks demo-data for a single day:
    <ul>
    <li>Check that all employees have logged their hours
        and advance their projects accordingly.
    <li>
    </ul>
} {
    # Default day if nothing has been specified: Just take the day
    # after the last hours logged
    if {"" == $day} {
	set day [db_string default_day "select max(day)::date + 1 from im_hours" -default ""]
	if {"" == $day} { set day [db_string now "'select now()::date - 365 from dual"] }
    }

    # Fake the creation_date of cost objects and audit information
    # Therefore store the information about the last objects
    set prev_object_id [db_string prev_object_id "select max(cost_id) from im_costs"]
    set prev_audit_id [db_string prev_audit "select last_value from im_audit_seq"]


    # Default user for logging data
    set admin_user_id [db_string admin_user "select min(user_id) from users where user_id > 0" -default 0]

    # Get the current im_audits.audit_id, so that we can 
    # move all new audit records to the specified day
    set start_audit_tz [db_string org_audit_tz "select now() from dual" -default 0]

    # -----------------------------------------------------
    # Get the list of employees together with their availability
    set employee_sql "
    	select	  e.employee_id,
		  coalesce(e.availability, 100.0) as availability
	from	  im_employees e,
		  cc_users u
	where	  u.user_id = e.employee_id and
		  e.employee_id in (select member_id from group_distinct_member_map where group_id = [im_employee_group_id])
   "
    db_foreach emps $employee_sql {
	set employee_hash($employee_id) $availability
    }

    # -----------------------------------------------------
    # Get the currently logged hours per employee
    set ts_sql "
	select	h.user_id,
		sum(h.hours) as hours
	from	im_hours h
	where	h.day = :day
	group by h.user_id
    "
    db_foreach ts_hours $ts_sql {
    	set ts_hash($user_id) $hours
    }

    # -----------------------------------------------------
    # Get the current assignments of the user to projects and tasks
    set direct_assig_sql "
    	select	u.user_id,
		p.project_id,
		bom.percentage
	from	im_projects p,
		im_timesheet_tasks t,
		acs_rels r,
		im_biz_object_members bom,
		users u
	where	p.project_id = t.task_id and
		r.rel_id = bom.rel_id and
		r.object_id_one = p.project_id and
		r.object_id_two in (
			select u.user_id from dual union 
			select group_id from group_element_index gei, membership_rels mr where gei.rel_id = mr.rel_id and gei.element_id = u.user_id
		) and
		bom.percentage is not null and
		coalesce(p.percent_completed, 0.0) < 100.0
    "
    db_foreach direct_assig $direct_assig_sql {
	set key "$user_id-$project_id"
	set project_direct_assig_hash($key) $percentage

	set direct_assig_sum 0
	if {[info exists direct_assig_hash($user_id)]} { set direct_assig_sum $direct_assig_hash($user_id) }
	set direct_assig_sum [expr $direct_assig_sum + $percentage]
	set direct_assig_hash($user_id) $direct_assig_sum
    }


    # -----------------------------------------------------
    # All available tasks to work on
    set open_tasks_sql "
	select	t.task_id,
		coalesce(p.percent_completed, 0) as percent_completed
	from	im_projects p,
		im_timesheet_tasks t
	where	p.project_id = t.task_id and
		coalesce(p.percent_completed, 0) < 100.0 and
		p.project_status_id in (select * from im_sub_categories([im_project_status_open])) and
		p.end_date >= :day
    "
    db_foreach open_tasks $open_tasks_sql {
	set open_tasks_hash($task_id) $percent_completed
    }


    # Log the hours for each and every employee in the company
    foreach uid [array names employee_hash] {
	ns_log Notice "im_demo_data_log_timesheet_hours: Logging hours for user_id=$uid"
	
	# Clean the array from last user
	array unset uid_hash
	
	# Check if there are direct assignments
	set percent_available $employee_hash($uid)
	set hours_today [expr round($percent_available * 8.0 * ((1.5 + rand()) / 2.0)) / 100.0]

	# Check if there are direct assignments for this user
	foreach tuple [array names project_direct_assig_hash] {
	    regexp {([^\-])\-([^\-])} $tuple match tuple_uid tuple_pid
	    if {$uid == $tuple_uid} {
	        set uid_hash($tuple_pid) $project_direct_assig_hash($tuple)
	    }
	}

	# Pick two random tasks where something is to do...
	if {"" == [array get uid_hash]} {
	    set task_list [array names open_tasks_hash]
	    set task_1 [util::random_list_element $task_list]
	    set task_2 [util::random_list_element $task_list]
	    set uid_hash($task_1) 50.0
	    set uid_hash($task_2) 50.0
	}

	# Normalize the uid_hash
	set percent_assigned_total 0
	foreach tid [array names uid_hash] {
	    set percent_assigned_total [expr $percent_assigned_total + $uid_hash($tid)]
	}

	ns_log Notice "im_demo_data_log_timesheet_hours: user=$uid will log $hours_today hours on tasks [array get uid_hash]"

	# Log hours on the specified tasks
	array set modified_projects_hash {}
	foreach tid [array names uid_hash] {

	    set perc_assig $uid_hash($tid)
	    set hours [expr $hours_today * $perc_assig / 100.0]

	    # Calculate the advance of the task
	    db_1row task_info "
	    	select	coalesce(t.planned_units, 8.0) as task_planned_units,
			coalesce(p.percent_completed, 0.0) as task_percent_completed,
			p.project_status_id old_project_status_id,
			p.parent_id as parent_id
		from	im_projects p,
			im_timesheet_tasks t
		where	p.project_id = t.task_id and
			t.task_id = :tid
	    "

	    # Efficiency of work greatly varies between 0.5 and 1.5 ...
	    set rand_factor [expr (0.5 + rand()) / 1.0 ]
	    set percent_done [expr 100.0 * $hours / $task_planned_units * $rand_factor]
	    set new_percent_completed [expr $task_percent_completed + $percent_done]
	    set new_project_status_id $old_project_status_id
	    if {$new_percent_completed >= 100.0} { 
		set new_percent_completed 100.0
		set new_project_status_id [im_project_status_closed]
	    }
	    ns_log Notice "im_demo_data_log_timesheet_hours: task(tid=$tid, est=$task_planned_units, compl=$task_percent_completed) gets $percent_done percent completed today"

	    db_dml hours_insert "
		insert into im_hours (user_id, project_id, day, hours) 
		values (:uid, :tid, :day, :hours)
	    "

	    db_dml task_update "
		update im_projects set 
			percent_completed = :new_percent_completed,
			project_status_id = :new_project_status_id
		where project_id = :tid
	    "
	    im_audit -object_id $tid

	    # Check the super-project if all of it's sub-projects are closed already
	    if {$new_project_status_id == [im_project_status_closed]} {
	        im_demo_data_project_close_done_projects -project_id $parent_id
	    }

	    # Remember the modified projects
	    set main_project_id [im_project_main_project $tid]
	    set modified_projects_hash($tid) $tid
	    set modified_projects_hash($main_project_id) $main_project_id
	}
    }

    # Update cache information of projects and audit
    foreach pid [array names modified_projects_hash] {
    
	# Update the cost caches
	im_timesheet_update_timesheet_cache -project_id $pid

	# Calculate the %completed of the project
	im_timesheet_project_advance $pid

	# Re-calculate the cost cache
	im_cost_update_project_cost_cache $pid
	
	# Write an audit record
	# im_audit -object_id $tid -user_id $admin_user_id -action "after_update" -comment "im_demo_data_log_timesheet_hours: Simulating hour logging"
    }

    # Patch costs objects
    db_dml patch_costs "update im_costs set effective_date = :day where cost_id > :prev_object_id"
    db_dml patch_objects "update acs_objects set creation_date = :day where object_id > :prev_object_id"

    # Move all audit records back to the specified day
    set end_audit_tz [db_string end_audit_tz "select now() from dual" -default 0]
    db_dml shift_audits "update im_audits set audit_date = :day where audit_date between :start_audit_tz and :end_audit_tz"
    db_dml shift_project_audits "update im_projects_audit set last_modified = :day where last_modified between :start_audit_tz and :end_audit_tz"

    # ad_return_complaint 1 "<pre>emp: [array get employee_hash]\nts: [array get ts_hash]\ndirect_assig: [array get direct_assig_hash]\ntasks: [array get open_tasks_hash]</pre>"

}
