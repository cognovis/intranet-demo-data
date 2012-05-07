# packages/intranet-demo-data/tcl/intranet-demo-data-procs.tcl
ad_library {

  Support procs for the intranet-demo-data package

  @author Frank Bergmann (frank.bergmann@project-open.com)
  @creation-date 2012-05-06

  @vss $Workfile: intranet-dynfield-procs.tcl $ $Revision$ $Date$
}



ad_proc im_demo_create_beaches {
    -day:required
} {
    The "Beach" are the projects for non-productive hours.
    These beaches are created per year.
    All users are assigned to the beaches, so that all users
    can log unproductive hours.
} {
    # -----------------------------------------------------
    # Check if there is a beach for day

    set beaches [db_list beach_count "
    	select	  project_id
	from	  im_projects main_p
	where	  main_p.parent_id is null and
		  main_p.start_date <= :day and
		  main_p.end_date >= :day and
		  main_p.company_id = [im_company_internal] and
		  lower(main_p.project_nr) like '%beach%'
    "]

    lappend beaches 0
#    ad_return_complaint 1 $beaches

    db_dml beach_open "
    	update im_projects
	set project_status_id = [im_project_status_open],
	    project_type_id = [im_project_type_other]
	where project_id in ([join $beaches ","])
    "

    db_1row info "
    	select	to_char(now(), 'YYYY') as year
	from	dual     
    "

    # Close all "beaches"
    set open_beaches [db_list open_beaches "
		select	project_id
		from	im_projects
		where	parent_id is null and
			project_status_id = [im_project_status_open] and
			(project_nr like '20%_beach' or project_nr like '20%_op') and
			project_nr not in (:year || '_beach', :year || '_op')
    "]
    foreach pid $open_beaches {
        ToDo: Remove this line once closing old beaches works
        db_dml close_beaches "
		update im_projects
		set	project_status_id = [im_project_status_closed]
		where	project_id = :pid
        "
    }



    # define the list of projects to create
    set beaches [list \
    	[list ""		"Beach $year"			"${year}_beach"			""				] \
    	[list "${year}_beach"	"Beach $year - Vacation"	"${year}_beach_vacation"	[im_profile_employees]		] \
    	[list "${year}_beach"	"Beach $year - Training"	"${year}_beach_training"	[im_profile_employees]		] \
    	[list ""		"Operations $year"		"${year}_op"			""				] \
    	[list "${year}_op"	"Operations $year - Marketing"	"${year}_op_marketing"		[im_profile_sales]		] \
    	[list "${year}_op"	"Operations $year - Sales"	"${year}_op_sales"		[im_profile_sales]		] \
    	[list "${year}_op"	"Operations $year - Other"	"${year}_op_other"		[im_profile_senior_managers] 	] \
    ]

    foreach tuple $beaches {
	set beach_parent [lindex $tuple 0]
	set beach_name [lindex $tuple 1]
	set beach_nr [lindex $tuple 2]
	set beach_group_id [lindex $tuple 3]
	set beach_parent_id [db_string beach_parent "select project_id from im_projects where project_nr = :beach_parent" -default ""]

	# Create new beach for the current year
	set beach_parent_null_sql "parent_id = :beach_parent_id"
	if {"" == $beach_parent_id} { set beach_parent_null_sql "parent_id is null" }

	set main_beach_id [db_string beach_exists "
		select	project_id
		from	im_projects
		where	project_nr = :beach_nr and
			$beach_parent_null_sql
	" -default ""]

	if {"" == $main_beach_id} {
	    set main_beach_id [project::new \
				   -project_name $beach_name \
				   -project_nr $beach_nr \
				   -project_path $beach_nr \
				   -company_id [im_company_internal] \
				   -parent_id $beach_parent_id \
				   -project_type_id [im_project_type_other] \
				   -project_status_id [im_project_status_open] \
	    ]
	}

	# Update some addional variables
	db_dml main_beach "
		update im_projects set
			project_lead_id = (select min(user_id) from users where user_id > 0),
			start_date = '${year}-01-01'::date,
			end_date = '${year}-12-31'::date
		where project_id = :main_beach_id
	 "

	# Make all employees members of the beach
	im_biz_object_add_role $beach_group_id $main_beach_id [im_biz_object_role_full_member]
    }

}


ad_proc im_demo_log_timesheet_hours {
    -day:required
} {
    Checks demo-data for a single day:
    <ul>
    <li>Check that all employees have logged their hours
        and advance their projects accordingly.
    <li>
    </ul>
} {
    # -----------------------------------------------------
    # Get the list of employees together with their availability
    set employee_sql "
    	select	  e.employee_id,
		  e.availability
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
	group by
		h.user_id
    "
    db_foreach ts_hours $ts_sql {
    	set ts_hash($user_id) $hours
    }

    # -----------------------------------------------------
    # Get the current assignments of the user to projects and tasks
    set assig_sql "
    	select	u.user_id,
		p.project_id,
		bom.percentage
	from	im_projects p,
		acs_rels r,
		im_biz_object_members bom,
		users u
	where	r.rel_id = bom.rel_id and
		r.object_id_one = p.project_id and
		r.object_id_two in (
			select u.user_id from dual union 
			select group_id from group_distinct_member_map where user_id = :user_id
		) and
		bom.percentage is not null
    "
    db_foreach assig $assig_sql {
	set key "$user_id-$project_id"
	set project_assig_hash($key) $percentage

	set assig_sum 0
	if {[info exists assig_hash($user_id)]} { set assig_sum $assig_hash($user_id) }
	set assig_sum [expr $assig_sum + $percentage]
	set assig_hash($user_id) $assig_sum
    }

    ad_return_complaint 1 "<pre>emp: [array get employee_hash]\nts: [array get ts_hash]\nassig: [array get assig_hash]\n</pre>"



}
