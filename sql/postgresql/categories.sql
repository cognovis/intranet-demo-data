-- intranet-demo-date/sql/postgresql/categories.sql
--
-- Setup "Tigerpond" company


-- Disable translation skills
update im_categories   set enabled_p = 'f'	where category = 'Source Language' and category_type = 'Intranet Skill Type';
update im_categories   set enabled_p = 'f'	where category = 'Target Language' and category_type = 'Intranet Skill Type';
update im_categories   set enabled_p = 'f'	where category = 'Sworn Language' and category_type = 'Intranet Skill Type';
update im_categories   set enabled_p = 'f'	where category = 'TM Tools' and category_type = 'Intranet Skill Type';
update im_categories   set enabled_p = 'f'	where category = 'LOC Tools' and category_type = 'Intranet Skill Type';
update im_categories   set enabled_p = 'f'	where category = 'Subjects' and category_type = 'Intranet Skill Type';
update im_categories   set enabled_p = 'f'	where category = 'Expected Quality' and category_type = 'Intranet Skill Type';
update im_categories   set enabled_p = 'f'	where category = 'Operating System' and category_type = 'Intranet Skill Type';

