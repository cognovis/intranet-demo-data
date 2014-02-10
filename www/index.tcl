ad_page_contract {

    @author Frank Bergmann frank.bergmann@project-open.com
    @creation-date 2012-05-10
    @cvs-id $Id$

} {

}

# ******************************************************
# Default & Security
# ******************************************************

set user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set title "Demo-Data"
set context [list [list "/intranet-dynfield/" "DynField"] [list "object-types" "Object Types"] $title]
set return_url [im_url_with_query]

# ******************************************************
# 
# ******************************************************

set elements {
    dow_pretty {
	label "DoW" 
    }
    day {
	label "Day" 
    }
    timesheet_hours_logged {
	label "TS Hours" 
    }
    employees_available {
	label "Emps Avail" 
    }
}


list::create \
    -name days_list \
    -multirow days_multirow \
    -key day \
    -no_data "No days pages" \
    -bulk_actions [list "Recalculate Day" recalculate-day "Recalculate Day"] \
    -bulk_action_export_vars { return_url } \
    -bulk_action_method POST \
    -orderby {
	page_url {orderby page_url}
	days_type {orderby days_type}
	default_p {orderby default_p}
    } \
    -filters { object_type {} } \
    -elements $elements


set days_multirow_sql "
	select	day.day,
		(	select	round(sum(e.availability / 100.0))
			from	im_employees e
			where	e.employee_id in (select member_id from group_distinct_member_map where group_id = [im_employee_group_id])
		) as employees_available,
		(	select	sum(h.hours)
			from	im_hours h
			where	h.day::date = day.day
		) as timesheet_hours_logged,
		to_char(day.day, 'D') as dow_idx
	from	im_day_enumerator('2013-01-01', now()::date) day
	order by
		day.day DESC
"

db_multirow -extend {delete_url dow_pretty} days_multirow get_pages $days_multirow_sql {
    set delete_url [export_vars -base "days-del" { object_type page_url }]
    set dow_pretty [lindex {"-" Sun Mon Tue Wed Thu Fri Sat "-"} $dow_idx]
}
