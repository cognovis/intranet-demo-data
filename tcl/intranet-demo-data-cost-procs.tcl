# packages/intranet-demo-data/tcl/intranet-demo-data-cost-procs.tcl
ad_library {

    Cost support
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date 2012-10-06
    
    @vss $Workfile: intranet-dynfield-procs.tcl $ $Revision$ $Date$
}


ad_proc im_demo_data_cost_create {
    { -day ""}
    -cost_type_id:required
    -project_id:required
} {
    Create a quote for the project
} {
    if {"" == $day} { set day "2012-01-01" }
    set default_hourly_rate [parameter::get_from_package_key -package_key "intranet-cost" -parameter "DefaultTimesheetHourlyCost" -default 30]
    set current_user_id [ad_get_user_id]
    set provider_id [im_company_internal]
    db_1row project_info "
	select	company_id
	from	im_projects
	where	project_id = :project_id
    "

    set project_task_sql "
	select	p.project_id as task_id,
		p.project_name as task_name,
		t.planned_units
	from	im_projects main_p,
		im_projects p,
		im_timesheet_tasks t
	where	main_p.project_id = :project_id and
		p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
		p.project_id = t.task_id and
		t.planned_units > 0
	order by p.tree_sortkey
    "
    set num_tasks [db_string num_tasks "select count(*) from ($project_task_sql) t"]
    
    if {$num_tasks > 10} {
        set project_task_sql "
		select	p.project_id as task_id,
			p.project_name as task_name,
			(select sum(planned_units) from im_timesheet_tasks t where task_id in (
				select	p.project_id
				from	im_projects sub_main_p,
					im_projects sub_p,
					im_timesheet_tasks t
				where	sub_main_p.project_id = p.project_id and
					sub_p.tree_sortkey between sub_main_p.tree_sortkey and tree_right(sub_main_p.tree_sortkey) and
					sub_p.project_id = t.task_id
			)) planned_units
		from	im_projects main_p,
			im_projects p
		where	main_p.project_id = :project_id and
			p.parent_id = main_p.project_id
		order by tree_sortkey
	"
    }
    set num_tasks [db_string num_tasks "select count(*) from ($project_task_sql) t"]
    set sum_hours [db_string sum_hour "select sum(planned_units) from ($project_task_sql) t"]

    set invoice_nr [im_next_invoice_nr -cost_type_id $cost_type_id]
    set invoice_status_id [im_cost_status_created]
    set invoice_type_id $cost_type_id
    set invoice_id [db_string new_quote "
	select im_invoice__new (
		null,			-- invoice_id
		'im_invoice',		-- object_type
		:day,			-- creation_date 
		:current_user_id,	-- creation_user
		'[ad_conn peeraddr]',	-- creation_ip
		null,			-- context_id
		:invoice_nr,		-- invoice_nr
		:company_id,		-- company_id
		:provider_id,		-- provider_id
		null,			-- company_contact_id
		:day,		-- invoice_date
		'EUR',			-- currency
		null,			-- invoice_template_id
		:invoice_status_id,	-- invoice_status_id
		:invoice_type_id,	-- invoice_type_id
		null,			-- payment_method_id
		30,			-- payment_days
		[expr 1.0 * $sum_hours * $default_hourly_rate],			-- amount
		0.0,			-- vat
		0.0,			-- tax
		''			-- note
	    )
    "]

    # Update the invoice itself
    set ttt {db_dml update_invoice "
	update im_invoices set 
		invoice_nr	= :invoice_nr,
		payment_method_id = :payment_method_id,
		company_contact_id = :company_contact_id,
		invoice_office_id = :invoice_office_id,
		discount_perc	= :discount_perc,
		discount_text	= :discount_text,
		surcharge_perc	= :surcharge_perc,
		surcharge_text	= :surcharge_text
	where
		invoice_id = :invoice_id
    "}
	
    db_dml update_costs "
	update im_costs set
		project_id	= :project_id,
		cost_name	= :invoice_nr,
		cost_nr		= :invoice_id
	where
		cost_id = :invoice_id
    "
  
    set cnt 0
    db_foreach project_tasks $project_task_sql {
	set item_id [db_nextval "im_invoice_items_seq"]
        set insert_invoice_items_sql "
        INSERT INTO im_invoice_items (
                item_id, item_name,
                project_id, invoice_id,
                item_units, item_uom_id,
                price_per_unit, currency,
                sort_order, item_type_id,
                item_material_id,
                item_status_id, description, task_id
        ) VALUES (
                :item_id, :task_name,
                :project_id, :invoice_id,
                :planned_units, [im_uom_hour],
                :default_hourly_rate, 'EUR',
                :cnt, null,
                null,
                null, '', :task_id
	)" 
        db_dml insert_invoice_items $insert_invoice_items_sql
	incr cnt
    }

    # Link the invoice to the project
    set rel_id [db_exec_plsql create_rel "
      select acs_rel__new (
             null,             -- rel_id
             'relationship',   -- rel_type
             :project_id,      -- object_id_one
             :invoice_id,      -- object_id_two
             null,             -- context_id
             null,             -- creation_user
             null             -- creation_ip
      )
    "]
}

