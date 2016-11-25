*&----------------------------
*&  Include           ZABAPGIT_PERSISTENCE
*&---------------------------------------------------------------------*

CLASS lcl_persistence_migrate DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS: run RAISING lcx_exception.

  PRIVATE SECTION.
    CONSTANTS:
      c_text TYPE string VALUE 'Generated by abapGit' ##NO_TEXT.

    CLASS-METHODS:
      migrate_repo
        RAISING lcx_exception,
      migrate_user
        RAISING lcx_exception,
      table_create
        RAISING lcx_exception,
      table_exists
        RETURNING VALUE(rv_exists) TYPE abap_bool,
      lock_create
        RAISING lcx_exception,
      lock_exists
        RETURNING VALUE(rv_exists) TYPE abap_bool.

ENDCLASS.

CLASS lcl_persistence_db DEFINITION FINAL CREATE PRIVATE FRIENDS lcl_app.

  PUBLIC SECTION.
    CONSTANTS:
      c_tabname TYPE tabname VALUE 'ZABAPGIT',
      c_lock    TYPE viewname VALUE 'EZABAPGIT'.

    TYPES: ty_type  TYPE c LENGTH 12.
    TYPES: ty_value TYPE c LENGTH 12.

    TYPES: BEGIN OF ty_content,
             type     TYPE ty_type,
             value    TYPE ty_value,
             data_str TYPE string,
           END OF ty_content,
           tt_content TYPE SORTED TABLE OF ty_content WITH UNIQUE KEY type value.

    METHODS:
      list_by_type
        IMPORTING iv_type           TYPE ty_type
        RETURNING VALUE(rt_content) TYPE tt_content,
      list
        RETURNING VALUE(rt_content) TYPE tt_content,
      add
        IMPORTING iv_type  TYPE ty_type
                  iv_value TYPE ty_content-value
                  iv_data  TYPE ty_content-data_str
        RAISING   lcx_exception,
      delete
        IMPORTING iv_type  TYPE ty_type
                  iv_value TYPE ty_content-value
        RAISING   lcx_exception,
      update
        IMPORTING iv_type  TYPE ty_type
                  iv_value TYPE ty_content-value
                  iv_data  TYPE ty_content-data_str
        RAISING   lcx_exception,
      modify
        IMPORTING iv_type  TYPE ty_type
                  iv_value TYPE ty_content-value
                  iv_data  TYPE ty_content-data_str
        RAISING   lcx_exception,
      read
        IMPORTING iv_type        TYPE ty_type
                  iv_value       TYPE ty_content-value
        RETURNING VALUE(rv_data) TYPE ty_content-data_str
        RAISING   lcx_not_found,
      lock
        IMPORTING iv_mode  TYPE enqmode DEFAULT 'E'
                  iv_type  TYPE ty_type
                  iv_value TYPE ty_content-value
        RAISING   lcx_exception.

  PRIVATE SECTION.
    METHODS: validate_xml
      IMPORTING iv_xml TYPE string
      RAISING   lcx_exception.

ENDCLASS.

CLASS lcl_persistence_repo DEFINITION FINAL.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_local_checksum,
             item  TYPE ty_item,
             files TYPE ty_file_signatures_tt,
           END OF ty_local_checksum.

    TYPES: ty_local_checksum_tt TYPE STANDARD TABLE OF ty_local_checksum WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_repo_xml,
             url             TYPE string,
             branch_name     TYPE string,
             sha1            TYPE ty_sha1,
             package         TYPE devclass,
             offline         TYPE sap_bool,
             local_checksums TYPE ty_local_checksum_tt,
             master_language TYPE spras,
             head_branch     TYPE string,   " HEAD symref of the repo, master branch
             write_protect   TYPE sap_bool, " Deny destructive ops: pull, switch branch ...
           END OF ty_repo_xml.

    TYPES: BEGIN OF ty_repo,
             key TYPE lcl_persistence_db=>ty_value.
        INCLUDE TYPE ty_repo_xml.
    TYPES: END OF ty_repo.
    TYPES: tt_repo TYPE STANDARD TABLE OF ty_repo WITH DEFAULT KEY.
    TYPES: tt_repo_keys TYPE STANDARD TABLE OF ty_repo-key WITH DEFAULT KEY.

    METHODS constructor.

    METHODS list
      RETURNING VALUE(rt_repos) TYPE tt_repo
      RAISING   lcx_exception.

    METHODS update_sha1
      IMPORTING iv_key         TYPE ty_repo-key
                iv_branch_sha1 TYPE ty_repo_xml-sha1
      RAISING   lcx_exception.

    METHODS update_local_checksums
      IMPORTING iv_key       TYPE ty_repo-key
                it_checksums TYPE ty_repo_xml-local_checksums
      RAISING   lcx_exception.

    METHODS update_url
      IMPORTING iv_key TYPE ty_repo-key
                iv_url TYPE ty_repo_xml-url
      RAISING   lcx_exception.

    METHODS update_branch_name
      IMPORTING iv_key         TYPE ty_repo-key
                iv_branch_name TYPE ty_repo_xml-branch_name
      RAISING   lcx_exception.

    METHODS update_head_branch
      IMPORTING iv_key         TYPE ty_repo-key
                iv_head_branch TYPE ty_repo_xml-head_branch
      RAISING   lcx_exception.

    METHODS update_offline
      IMPORTING iv_key     TYPE ty_repo-key
                iv_offline TYPE ty_repo_xml-offline
      RAISING   lcx_exception.

    METHODS add
      IMPORTING iv_url         TYPE string
                iv_branch_name TYPE string
                iv_branch      TYPE ty_sha1 OPTIONAL
                iv_package     TYPE devclass
                iv_offline     TYPE sap_bool DEFAULT abap_false
      RETURNING VALUE(rv_key)  TYPE ty_repo-key
      RAISING   lcx_exception.

    METHODS delete
      IMPORTING iv_key TYPE ty_repo-key
      RAISING   lcx_exception.

    METHODS read
      IMPORTING iv_key         TYPE ty_repo-key
      RETURNING VALUE(rs_repo) TYPE ty_repo
      RAISING   lcx_exception
                lcx_not_found.

    METHODS lock
      IMPORTING iv_mode TYPE enqmode
                iv_key  TYPE ty_repo-key
      RAISING   lcx_exception.

  PRIVATE SECTION.
    CONSTANTS c_type_repo TYPE lcl_persistence_db=>ty_type VALUE 'REPO'.

    DATA: mo_db TYPE REF TO lcl_persistence_db.

    METHODS from_xml
      IMPORTING iv_repo_xml_string TYPE string
      RETURNING VALUE(rs_repo)     TYPE ty_repo_xml
      RAISING   lcx_exception.

    METHODS to_xml
      IMPORTING is_repo                   TYPE ty_repo
      RETURNING VALUE(rv_repo_xml_string) TYPE string.

    METHODS get_next_id
      RETURNING VALUE(rv_next_repo_id) TYPE lcl_persistence_db=>ty_content-value
      RAISING   lcx_exception.

ENDCLASS.

CLASS lcl_persistence_background DEFINITION FINAL.

  PUBLIC SECTION.

    CONSTANTS: BEGIN OF c_method,
                 nothing TYPE string VALUE 'nothing' ##NO_TEXT,
                 pull    TYPE string VALUE 'pull' ##NO_TEXT,
                 push    TYPE string VALUE 'push' ##NO_TEXT,
               END OF c_method.

    CONSTANTS: BEGIN OF c_amethod,
                 fixed TYPE string VALUE 'fixed' ##NO_TEXT,
                 auto  TYPE string VALUE 'auto' ##NO_TEXT,
               END OF c_amethod.

    TYPES: BEGIN OF ty_xml,
             method   TYPE string,
             username TYPE string,
             password TYPE string,
             amethod  TYPE string,
             aname    TYPE string,
             amail    TYPE string,
           END OF ty_xml.

    TYPES: BEGIN OF ty_background,
             key TYPE lcl_persistence_db=>ty_value.
        INCLUDE TYPE ty_xml.
    TYPES: END OF ty_background.
    TYPES: tt_background TYPE STANDARD TABLE OF ty_background WITH DEFAULT KEY.

    METHODS constructor.

    METHODS list
      RETURNING VALUE(rt_list) TYPE tt_background
      RAISING   lcx_exception.

    METHODS modify
      IMPORTING is_data TYPE ty_background
      RAISING   lcx_exception.

    METHODS delete
      IMPORTING iv_key TYPE ty_background-key
      RAISING   lcx_exception.

    METHODS exists
      IMPORTING iv_key        TYPE ty_background-key
      RETURNING VALUE(rv_yes) TYPE abap_bool
      RAISING   lcx_exception.

  PRIVATE SECTION.
    CONSTANTS c_type TYPE lcl_persistence_db=>ty_type VALUE 'BACKGROUND'.

    DATA: mo_db   TYPE REF TO lcl_persistence_db,
          mt_jobs TYPE tt_background.

    METHODS from_xml
      IMPORTING iv_string     TYPE string
      RETURNING VALUE(rs_xml) TYPE ty_xml
      RAISING   lcx_exception.

    METHODS to_xml
      IMPORTING is_background    TYPE ty_background
      RETURNING VALUE(rv_string) TYPE string.

ENDCLASS.     "lcl_persistence_background DEFINITION

CLASS lcl_persistence_background IMPLEMENTATION.

  METHOD constructor.
    mo_db = lcl_app=>db( ).
  ENDMETHOD.

  METHOD list.

    DATA: lt_list TYPE lcl_persistence_db=>tt_content,
          ls_xml  TYPE ty_xml.

    FIELD-SYMBOLS: <ls_list>   LIKE LINE OF lt_list,
                   <ls_output> LIKE LINE OF rt_list.

    IF lines( mt_jobs ) > 0.
      rt_list = mt_jobs.
      RETURN.
    ENDIF.


    lt_list = mo_db->list_by_type( c_type ).

    LOOP AT lt_list ASSIGNING <ls_list>.
      ls_xml = from_xml( <ls_list>-data_str ).

      APPEND INITIAL LINE TO rt_list ASSIGNING <ls_output>.
      MOVE-CORRESPONDING ls_xml TO <ls_output>.
      <ls_output>-key = <ls_list>-value.
    ENDLOOP.

    mt_jobs = rt_list.

  ENDMETHOD.

  METHOD exists.

    list( ). " Ensure mt_jobs is populated
    READ TABLE mt_jobs WITH KEY key = iv_key TRANSPORTING NO FIELDS.
    rv_yes = boolc( sy-subrc = 0 ).

  ENDMETHOD.  "exists

  METHOD modify.

    ASSERT NOT is_data-key IS INITIAL.

    mo_db->modify(
      iv_type  = c_type
      iv_value = is_data-key
      iv_data  = to_xml( is_data ) ).

    DELETE mt_jobs WHERE key = is_data-key.
    APPEND is_data TO mt_jobs.

  ENDMETHOD.

  METHOD delete.

    TRY.
        mo_db->read( iv_type  = c_type
                     iv_value = iv_key ).
      CATCH lcx_not_found.
        RETURN.
    ENDTRY.

    mo_db->delete( iv_type  = c_type
                   iv_value = iv_key ).

    DELETE mt_jobs WHERE key = iv_key.

  ENDMETHOD.

  METHOD from_xml.
    CALL TRANSFORMATION id
      OPTIONS value_handling = 'accept_data_loss'
      SOURCE XML iv_string
      RESULT data = rs_xml ##NO_TEXT.
  ENDMETHOD.

  METHOD to_xml.
    DATA: ls_xml TYPE ty_xml.

    MOVE-CORRESPONDING is_background TO ls_xml.

    CALL TRANSFORMATION id
      SOURCE data = ls_xml
      RESULT XML rv_string.
  ENDMETHOD.

ENDCLASS.         " lcl_persistence_background IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_persistence_user DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_persistence_user DEFINITION FINAL CREATE PRIVATE FRIENDS lcl_app.

  PUBLIC SECTION.

    TYPES: tt_favorites TYPE lcl_persistence_repo=>tt_repo_keys.

    METHODS set_username
      IMPORTING iv_username TYPE string
      RAISING   lcx_exception.

    METHODS get_username
      RETURNING VALUE(rv_username) TYPE string
      RAISING   lcx_exception.

    METHODS set_email
      IMPORTING iv_email TYPE string
      RAISING   lcx_exception.

    METHODS get_email
      RETURNING VALUE(rv_email) TYPE string
      RAISING   lcx_exception.

    METHODS set_repo_show
      IMPORTING iv_key TYPE lcl_persistence_repo=>ty_repo-key
      RAISING   lcx_exception.

    METHODS get_repo_show
      RETURNING VALUE(rv_key) TYPE lcl_persistence_repo=>ty_repo-key
      RAISING   lcx_exception.

    METHODS set_repo_username
      IMPORTING iv_url      TYPE lcl_persistence_repo=>ty_repo-url
                iv_username TYPE string
      RAISING   lcx_exception.

    METHODS get_repo_username
      IMPORTING iv_url             TYPE lcl_persistence_repo=>ty_repo-url
      RETURNING VALUE(rv_username) TYPE string
      RAISING   lcx_exception.

    METHODS set_repo_email
      IMPORTING iv_url   TYPE lcl_persistence_repo=>ty_repo-url
                iv_email TYPE string
      RAISING   lcx_exception.

    METHODS get_repo_email
      IMPORTING iv_url          TYPE lcl_persistence_repo=>ty_repo-url
      RETURNING VALUE(rv_email) TYPE string
      RAISING   lcx_exception.

    METHODS toggle_hide_files
      RETURNING VALUE(rv_hide) TYPE abap_bool
      RAISING   lcx_exception.

    METHODS get_hide_files
      RETURNING VALUE(rv_hide) TYPE abap_bool
      RAISING   lcx_exception.

    METHODS toggle_changes_only
      RETURNING VALUE(rv_changes_only) TYPE abap_bool
      RAISING   lcx_exception.

    METHODS get_changes_only
      RETURNING VALUE(rv_changes_only) TYPE abap_bool
      RAISING   lcx_exception.

    METHODS get_favorites
      RETURNING VALUE(rt_favorites) TYPE tt_favorites
      RAISING   lcx_exception.

    METHODS toggle_favorite
      IMPORTING iv_repo_key TYPE lcl_persistence_repo=>ty_repo-key
      RAISING   lcx_exception.

    METHODS is_favorite_repo
      IMPORTING iv_repo_key   TYPE lcl_persistence_repo=>ty_repo-key
      RETURNING VALUE(rv_yes) TYPE abap_bool
      RAISING   lcx_exception.

  PRIVATE SECTION.
    CONSTANTS c_type_user TYPE lcl_persistence_db=>ty_type VALUE 'USER'.

    DATA: mv_user TYPE xubname.

    TYPES: BEGIN OF ty_repo_config,
             url      TYPE lcl_persistence_repo=>ty_repo-url,
             username TYPE string,
             email    TYPE string,
           END OF ty_repo_config.
    TYPES: ty_repo_config_tt TYPE STANDARD TABLE OF ty_repo_config WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_user,
             username     TYPE string,
             email        TYPE string,
             repo_show    TYPE lcl_persistence_repo=>ty_repo-key,
             repo_config  TYPE ty_repo_config_tt,
             hide_files   TYPE abap_bool,
             changes_only TYPE abap_bool,
             favorites    TYPE tt_favorites,
           END OF ty_user.

    METHODS constructor
      IMPORTING iv_user TYPE xubname DEFAULT sy-uname.

    METHODS from_xml
      IMPORTING iv_xml         TYPE string
      RETURNING VALUE(rs_user) TYPE ty_user
      RAISING   lcx_exception.

    METHODS to_xml
      IMPORTING is_user       TYPE ty_user
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS read
      RETURNING VALUE(rs_user) TYPE ty_user
      RAISING   lcx_exception.

    METHODS update
      IMPORTING is_user TYPE ty_user
      RAISING   lcx_exception.

    METHODS read_repo_config
      IMPORTING iv_url                TYPE lcl_persistence_repo=>ty_repo-url
      RETURNING VALUE(rs_repo_config) TYPE ty_repo_config
      RAISING   lcx_exception.

    METHODS update_repo_config
      IMPORTING iv_url         TYPE lcl_persistence_repo=>ty_repo-url
                is_repo_config TYPE ty_repo_config
      RAISING   lcx_exception.

ENDCLASS.             "lcl_persistence_user DEFINITION

CLASS lcl_persistence_user IMPLEMENTATION.

  METHOD constructor.
    mv_user = iv_user.
  ENDMETHOD.

  METHOD from_xml.

    DATA: lv_xml TYPE string.

    lv_xml = iv_xml.

* fix downward compatibility
    REPLACE ALL OCCURRENCES OF '<_--28C_TYPE_USER_--29>' IN lv_xml WITH '<USER>'.
    REPLACE ALL OCCURRENCES OF '</_--28C_TYPE_USER_--29>' IN lv_xml WITH '</USER>'.

    CALL TRANSFORMATION id
      OPTIONS value_handling = 'accept_data_loss'
      SOURCE XML lv_xml
      RESULT user = rs_user ##NO_TEXT.
  ENDMETHOD.

  METHOD to_xml.
    CALL TRANSFORMATION id
      SOURCE user = is_user
      RESULT XML rv_xml.
  ENDMETHOD.

  METHOD read.

    DATA: lv_xml TYPE string.

    TRY.
        lv_xml = lcl_app=>db( )->read(
          iv_type  = c_type_user
          iv_value = mv_user ).
      CATCH lcx_not_found.
        RETURN.
    ENDTRY.

    rs_user = from_xml( lv_xml ).

  ENDMETHOD.

  METHOD set_repo_show.

    DATA: ls_user TYPE ty_user.


    ls_user = read( ).
    ls_user-repo_show = iv_key.
    update( ls_user ).

    COMMIT WORK AND WAIT.

  ENDMETHOD.

  METHOD get_repo_show.

    rv_key = read( )-repo_show.

  ENDMETHOD.

  METHOD update.

    DATA: lv_xml TYPE string.

    lv_xml = to_xml( is_user ).

    lcl_app=>db( )->modify(
      iv_type  = c_type_user
      iv_value = mv_user
      iv_data  = lv_xml ).

  ENDMETHOD.

  METHOD set_username.

    DATA: ls_user TYPE ty_user.


    ls_user = read( ).

    ls_user-username = iv_username.

    update( ls_user ).

  ENDMETHOD.

  METHOD get_username.

    rv_username = read( )-username.

  ENDMETHOD.

  METHOD set_email.

    DATA: ls_user TYPE ty_user.


    ls_user = read( ).
    ls_user-email = iv_email.
    update( ls_user ).

  ENDMETHOD.

  METHOD get_email.

    rv_email = read( )-email.

  ENDMETHOD.

  METHOD read_repo_config.
    DATA: lt_repo_config TYPE ty_repo_config_tt,
          lv_key         TYPE string.

    lv_key         = to_lower( iv_url ).
    lt_repo_config = read( )-repo_config.
    READ TABLE lt_repo_config INTO rs_repo_config WITH KEY url = lv_key.

  ENDMETHOD.  "read_repo_config

  METHOD update_repo_config.
    DATA: ls_user TYPE ty_user,
          lv_key  TYPE string.
    FIELD-SYMBOLS <repo_config> TYPE ty_repo_config.

    ls_user = read( ).
    lv_key  = to_lower( iv_url ).

    READ TABLE ls_user-repo_config ASSIGNING <repo_config> WITH KEY url = lv_key.
    IF sy-subrc IS NOT INITIAL.
      APPEND INITIAL LINE TO ls_user-repo_config ASSIGNING <repo_config>.
    ENDIF.
    <repo_config>     = is_repo_config.
    <repo_config>-url = lv_key.

    update( ls_user ).

  ENDMETHOD.  "update_repo_config

  METHOD set_repo_username.

    DATA: ls_repo_config TYPE ty_repo_config.

    ls_repo_config          = read_repo_config( iv_url ).
    ls_repo_config-username = iv_username.
    update_repo_config( iv_url = iv_url is_repo_config = ls_repo_config ).

  ENDMETHOD.  "set_repo_username

  METHOD get_repo_username.

    rv_username = read_repo_config( iv_url )-username.

  ENDMETHOD.  "get_repo_username

  METHOD set_repo_email.

    DATA: ls_repo_config TYPE ty_repo_config.

    ls_repo_config       = read_repo_config( iv_url ).
    ls_repo_config-email = iv_email.
    update_repo_config( iv_url = iv_url is_repo_config = ls_repo_config ).

  ENDMETHOD.  "set_repo_email

  METHOD get_repo_email.

    rv_email = read_repo_config( iv_url )-email.

  ENDMETHOD.  "get_repo_email

  METHOD toggle_hide_files.

    DATA ls_user TYPE ty_user.

    ls_user = read( ).
    ls_user-hide_files = boolc( ls_user-hide_files = abap_false ).
    update( ls_user ).

    rv_hide = ls_user-hide_files.

  ENDMETHOD. "toggle_hide_files

  METHOD get_hide_files.

    rv_hide = read( )-hide_files.

  ENDMETHOD. "get_hide_files

  METHOD toggle_changes_only.

    DATA ls_user TYPE ty_user.

    ls_user = read( ).
    ls_user-changes_only = boolc( ls_user-changes_only = abap_false ).
    update( ls_user ).

    rv_changes_only = ls_user-changes_only.

  ENDMETHOD. "toggle_changes_only

  METHOD get_changes_only.

    rv_changes_only = read( )-changes_only.

  ENDMETHOD. "get_changes_only

  METHOD get_favorites.

    rt_favorites = read( )-favorites.

  ENDMETHOD.  "get_favorites

  METHOD toggle_favorite.

    DATA: ls_user TYPE ty_user.

    ls_user = read( ).

    READ TABLE ls_user-favorites TRANSPORTING NO FIELDS
      WITH KEY table_line = iv_repo_key.

    IF sy-subrc = 0.
      DELETE ls_user-favorites INDEX sy-tabix.
    ELSE.
      APPEND iv_repo_key TO ls_user-favorites.
    ENDIF.

    update( ls_user ).

  ENDMETHOD.  " toggle_favorite.

  METHOD is_favorite_repo.

    DATA: lt_favorites TYPE tt_favorites.

    lt_favorites = get_favorites( ).

    READ TABLE lt_favorites TRANSPORTING NO FIELDS
      WITH KEY table_line = iv_repo_key.

    rv_yes = boolc( sy-subrc = 0 ).

  ENDMETHOD.  " is_favorite_repo.

ENDCLASS.


*----------------------------------------------------------------------*
*       CLASS lcl_persistence_db
*----------------------------------------------------------------------*

CLASS lcl_persistence_db IMPLEMENTATION.

  METHOD list_by_type.
    SELECT * FROM (c_tabname)
      INTO TABLE rt_content
      WHERE type = iv_type.                               "#EC CI_SUBRC
  ENDMETHOD.

  METHOD list.
    SELECT * FROM (c_tabname)
      INTO TABLE rt_content.                              "#EC CI_SUBRC
  ENDMETHOD.

  METHOD lock.

    CALL FUNCTION 'ENQUEUE_EZABAPGIT'
      EXPORTING
        mode_zabapgit  = iv_mode
        type           = iv_type
        value          = iv_value
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      lcx_exception=>raise( |Could not aquire lock { iv_type } { iv_value }| ).
    ENDIF.

* trigger dummy update task to automatically release locks at commit
    CALL FUNCTION 'BANK_OBJ_WORKL_RELEASE_LOCKS'
      IN UPDATE TASK.

  ENDMETHOD.

  METHOD add.

    DATA ls_table TYPE ty_content.

    ls_table-type  = iv_type.
    ls_table-value = iv_value.
    ls_table-data_str = iv_data.

    INSERT (c_tabname) FROM ls_table.                     "#EC CI_SUBRC
    ASSERT sy-subrc = 0.

  ENDMETHOD.

  METHOD delete.

    lock( iv_type  = iv_type
          iv_value = iv_value ).

    DELETE FROM (c_tabname)
      WHERE type = iv_type
      AND value = iv_value.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'DB Delete failed' ).
    ENDIF.

  ENDMETHOD.

  METHOD validate_xml.

    lcl_xml_pretty=>print(
      iv_xml           = iv_xml
      iv_ignore_errors = abap_false ).

  ENDMETHOD.

  METHOD update.

    validate_xml( iv_data ).

    lock( iv_type  = iv_type
          iv_value = iv_value ).

    UPDATE (c_tabname) SET data_str = iv_data
      WHERE type = iv_type
      AND value = iv_value.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'DB update failed' ).
    ENDIF.

  ENDMETHOD.

  METHOD modify.

    DATA: ls_content TYPE ty_content.

    lock( iv_type  = iv_type
          iv_value = iv_value ).

    ls_content-type  = iv_type.
    ls_content-value = iv_value.
    ls_content-data_str = iv_data.

    MODIFY (c_tabname) FROM ls_content.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'DB modify failed' ).
    ENDIF.

  ENDMETHOD.

  METHOD read.

    SELECT SINGLE data_str FROM (c_tabname) INTO rv_data
      WHERE type = iv_type
      AND value = iv_value.                               "#EC CI_SUBRC
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcx_not_found.
    ENDIF.

  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
*       CLASS lcl_persistence_repo
*----------------------------------------------------------------------*

CLASS lcl_persistence_repo IMPLEMENTATION.

  METHOD add.

    DATA: ls_repo        TYPE ty_repo,
          lv_repo_as_xml TYPE string.


    ls_repo-url          = iv_url.
    ls_repo-branch_name  = iv_branch_name.
    ls_repo-sha1         = iv_branch.
    ls_repo-package      = iv_package.
    ls_repo-offline      = iv_offline.
    ls_repo-master_language = sy-langu.

    lv_repo_as_xml = to_xml( ls_repo ).

    rv_key = get_next_id( ).

    mo_db->add( iv_type  = c_type_repo
                iv_value = rv_key
                iv_data  = lv_repo_as_xml ).

  ENDMETHOD.

  METHOD delete.

    DATA: lo_background TYPE REF TO lcl_persistence_background.

    CREATE OBJECT lo_background.
    lo_background->delete( iv_key ).

    mo_db->delete( iv_type  = c_type_repo
                   iv_value = iv_key ).

  ENDMETHOD.

  METHOD update_local_checksums.

    DATA: lt_content TYPE lcl_persistence_db=>tt_content,
          ls_content LIKE LINE OF lt_content,
          ls_repo    TYPE ty_repo.


    ASSERT NOT iv_key IS INITIAL.

    TRY.
        ls_repo = read( iv_key ).
      CATCH lcx_not_found.
        lcx_exception=>raise( 'key not found' ).
    ENDTRY.

    ls_repo-local_checksums = it_checksums.
    ls_content-data_str = to_xml( ls_repo ).

    mo_db->update( iv_type  = c_type_repo
                   iv_value = iv_key
                   iv_data  = ls_content-data_str ).

  ENDMETHOD.

  METHOD update_url.

    DATA: lt_content TYPE lcl_persistence_db=>tt_content,
          ls_content LIKE LINE OF lt_content,
          ls_repo    TYPE ty_repo.


    IF iv_url IS INITIAL.
      lcx_exception=>raise( 'update, url empty' ).
    ENDIF.

    ASSERT NOT iv_key IS INITIAL.

    TRY.
        ls_repo = read( iv_key ).
      CATCH lcx_not_found.
        lcx_exception=>raise( 'key not found' ).
    ENDTRY.

    ls_repo-url = iv_url.
    ls_content-data_str = to_xml( ls_repo ).

    mo_db->update( iv_type  = c_type_repo
                   iv_value = iv_key
                   iv_data  = ls_content-data_str ).

  ENDMETHOD.

  METHOD update_branch_name.

    DATA: lt_content TYPE lcl_persistence_db=>tt_content,
          ls_content LIKE LINE OF lt_content,
          ls_repo    TYPE ty_repo.


    ASSERT NOT iv_key IS INITIAL.

    TRY.
        ls_repo = read( iv_key ).
      CATCH lcx_not_found.
        lcx_exception=>raise( 'key not found' ).
    ENDTRY.

    ls_repo-branch_name = iv_branch_name.
    ls_content-data_str = to_xml( ls_repo ).

    mo_db->update( iv_type  = c_type_repo
                   iv_value = iv_key
                   iv_data  = ls_content-data_str ).

  ENDMETHOD.

  METHOD update_head_branch.

    DATA: lt_content TYPE lcl_persistence_db=>tt_content,
          ls_content LIKE LINE OF lt_content,
          ls_repo    TYPE ty_repo.


    ASSERT NOT iv_key IS INITIAL.

    TRY.
        ls_repo = read( iv_key ).
      CATCH lcx_not_found.
        lcx_exception=>raise( 'key not found' ).
    ENDTRY.

    ls_repo-head_branch = iv_head_branch.
    ls_content-data_str = to_xml( ls_repo ).

    mo_db->update( iv_type  = c_type_repo
                   iv_value = iv_key
                   iv_data  = ls_content-data_str ).

  ENDMETHOD.  "update_head_branch

  METHOD update_offline.

    DATA: lt_content TYPE lcl_persistence_db=>tt_content,
          ls_content LIKE LINE OF lt_content,
          ls_repo    TYPE ty_repo.

    ASSERT NOT iv_key IS INITIAL.

    TRY.
        ls_repo = read( iv_key ).
      CATCH lcx_not_found.
        lcx_exception=>raise( 'key not found' ).
    ENDTRY.

    ls_repo-offline = iv_offline.
    ls_content-data_str = to_xml( ls_repo ).

    mo_db->update( iv_type  = c_type_repo
                   iv_value = iv_key
                   iv_data  = ls_content-data_str ).

  ENDMETHOD.  "update_offline

  METHOD update_sha1.

    DATA: lt_content TYPE lcl_persistence_db=>tt_content,
          ls_content LIKE LINE OF lt_content,
          ls_repo    TYPE ty_repo.


    ASSERT NOT iv_key IS INITIAL.

    TRY.
        ls_repo = read( iv_key ).
      CATCH lcx_not_found.
        lcx_exception=>raise( 'key not found' ).
    ENDTRY.

    ls_repo-sha1 = iv_branch_sha1.
    ls_content-data_str = to_xml( ls_repo ).

    mo_db->update( iv_type  = c_type_repo
                   iv_value = iv_key
                   iv_data  = ls_content-data_str ).

  ENDMETHOD.

  METHOD read.

    DATA lt_repo TYPE tt_repo.

    lt_repo = list( ).

    READ TABLE lt_repo INTO rs_repo WITH KEY key = iv_key.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcx_not_found.
    ENDIF.

  ENDMETHOD.

  METHOD get_next_id.

* todo: Lock the complete persistence in order to prevent concurrent repo-creation
* however the current approach will most likely work in almost all cases

    DATA: lt_content TYPE lcl_persistence_db=>tt_content.

    FIELD-SYMBOLS: <ls_content> LIKE LINE OF lt_content.


    rv_next_repo_id = 1.

    lt_content = mo_db->list_by_type( c_type_repo ).
    LOOP AT lt_content ASSIGNING <ls_content>.
      IF <ls_content>-value >= rv_next_repo_id.
        rv_next_repo_id = <ls_content>-value + 1.
      ENDIF.
    ENDLOOP.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = rv_next_repo_id
      IMPORTING
        output = rv_next_repo_id.

  ENDMETHOD.

  METHOD list.

    DATA: lt_content TYPE lcl_persistence_db=>tt_content,
          ls_content LIKE LINE OF lt_content,
          ls_repo    LIKE LINE OF rt_repos.


    lt_content = mo_db->list_by_type( c_type_repo ).

    LOOP AT lt_content INTO ls_content.
      MOVE-CORRESPONDING from_xml( ls_content-data_str ) TO ls_repo.
      ls_repo-key = ls_content-value.
      INSERT ls_repo INTO TABLE rt_repos.
    ENDLOOP.

  ENDMETHOD.

  METHOD from_xml.

    DATA: lv_xml TYPE string.

    lv_xml = iv_repo_xml_string.

* fix downward compatibility
    REPLACE ALL OCCURRENCES OF '<_--28C_TYPE_REPO_--29>' IN lv_xml WITH '<REPO>'.
    REPLACE ALL OCCURRENCES OF '</_--28C_TYPE_REPO_--29>' IN lv_xml WITH '</REPO>'.

    CALL TRANSFORMATION id
      OPTIONS value_handling = 'accept_data_loss'
      SOURCE XML lv_xml
      RESULT repo = rs_repo ##NO_TEXT.

    IF rs_repo IS INITIAL.
      lcx_exception=>raise( 'Inconsistent repo metadata' ).
    ENDIF.

* field master_language is new, so default it for old repositories
    IF rs_repo-master_language IS INITIAL.
      rs_repo-master_language = sy-langu.
    ENDIF.
  ENDMETHOD.

  METHOD to_xml.

    DATA: ls_xml TYPE ty_repo_xml.


    MOVE-CORRESPONDING is_repo TO ls_xml.

    CALL TRANSFORMATION id
      SOURCE repo = ls_xml
      RESULT XML rv_repo_xml_string.
  ENDMETHOD.

  METHOD constructor.
    mo_db = lcl_app=>db( ).
  ENDMETHOD.

  METHOD lock.

    mo_db->lock( iv_mode  = iv_mode
                 iv_type  = c_type_repo
                 iv_value = iv_key ).

  ENDMETHOD.

ENDCLASS.

CLASS lcl_persistence_migrate IMPLEMENTATION.

  METHOD run.

    IF table_exists( ) = abap_false.
      table_create( ).
    ENDIF.

    IF lock_exists( ) = abap_false.
      lock_create( ).

      migrate_repo( ).
      migrate_user( ).
    ENDIF.

  ENDMETHOD.

  METHOD migrate_repo.

    DATA: lt_repo TYPE lcl_persistence=>ty_repos_persi_tt,
          lo_repo TYPE REF TO lcl_persistence,
          lo_new  TYPE REF TO lcl_persistence_repo,
          ls_repo LIKE LINE OF lt_repo.


    CREATE OBJECT lo_repo.
    CREATE OBJECT lo_new.

    lt_repo = lo_repo->list( ).

    LOOP AT lt_repo INTO ls_repo.
      lo_new->add( iv_url         = ls_repo-url
                   iv_branch_name = ls_repo-branch_name
                   iv_branch      = ls_repo-sha1
                   iv_package     = ls_repo-package
                   iv_offline     = ls_repo-offline ).
    ENDLOOP.
  ENDMETHOD.

  METHOD migrate_user.

    DATA: lo_user  TYPE REF TO lcl_persistence_user,
          lt_users TYPE lcl_user=>ty_user_tt.

    FIELD-SYMBOLS: <ls_user> LIKE LINE OF lt_users.


    lt_users = lcl_user=>list( ).
    LOOP AT lt_users ASSIGNING <ls_user>.
      lo_user = lcl_app=>user( <ls_user>-user ).
      lo_user->set_username( <ls_user>-username ).
      lo_user->set_email( <ls_user>-email ).
    ENDLOOP.

  ENDMETHOD.

  METHOD lock_exists.

    DATA: lv_viewname TYPE dd25l-viewname.


    SELECT SINGLE viewname FROM dd25l INTO lv_viewname
      WHERE viewname = lcl_persistence_db=>c_lock.
    rv_exists = boolc( sy-subrc = 0 ).

  ENDMETHOD.

  METHOD lock_create.

    DATA: lv_obj_name TYPE tadir-obj_name,
          ls_dd25v    TYPE dd25v,
          lt_dd26e    TYPE STANDARD TABLE OF dd26e WITH DEFAULT KEY,
          lt_dd27p    TYPE STANDARD TABLE OF dd27p WITH DEFAULT KEY.

    FIELD-SYMBOLS: <ls_dd26e> LIKE LINE OF lt_dd26e,
                   <ls_dd27p> LIKE LINE OF lt_dd27p.


    ls_dd25v-viewname   = lcl_persistence_db=>c_lock.
    ls_dd25v-aggtype    = 'E'.
    ls_dd25v-roottab    = lcl_persistence_db=>c_tabname.
    ls_dd25v-ddlanguage = gc_english.
    ls_dd25v-ddtext     = c_text.

    APPEND INITIAL LINE TO lt_dd26e ASSIGNING <ls_dd26e>.
    <ls_dd26e>-viewname   = lcl_persistence_db=>c_lock.
    <ls_dd26e>-tabname    = lcl_persistence_db=>c_tabname.
    <ls_dd26e>-tabpos     = '0001'.
    <ls_dd26e>-fortabname = lcl_persistence_db=>c_tabname.
    <ls_dd26e>-enqmode    = 'E'.

    APPEND INITIAL LINE TO lt_dd27p ASSIGNING <ls_dd27p>.
    <ls_dd27p>-viewname  = lcl_persistence_db=>c_lock.
    <ls_dd27p>-objpos    = '0001'.
    <ls_dd27p>-viewfield = 'TYPE'.
    <ls_dd27p>-tabname   = lcl_persistence_db=>c_tabname.
    <ls_dd27p>-fieldname = 'TYPE'.
    <ls_dd27p>-keyflag   = abap_true.

    APPEND INITIAL LINE TO lt_dd27p ASSIGNING <ls_dd27p>.
    <ls_dd27p>-viewname  = lcl_persistence_db=>c_lock.
    <ls_dd27p>-objpos    = '0002'.
    <ls_dd27p>-viewfield = 'VALUE'.
    <ls_dd27p>-tabname   = lcl_persistence_db=>c_tabname.
    <ls_dd27p>-fieldname = 'VALUE'.
    <ls_dd27p>-keyflag   = abap_true.

    CALL FUNCTION 'DDIF_ENQU_PUT'
      EXPORTING
        name              = lcl_persistence_db=>c_lock
        dd25v_wa          = ls_dd25v
      TABLES
        dd26e_tab         = lt_dd26e
        dd27p_tab         = lt_dd27p
      EXCEPTIONS
        enqu_not_found    = 1
        name_inconsistent = 2
        enqu_inconsistent = 3
        put_failure       = 4
        put_refused       = 5
        OTHERS            = 6.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'migrate, error from DDIF_ENQU_PUT' ).
    ENDIF.

    lv_obj_name = lcl_persistence_db=>c_lock.
    CALL FUNCTION 'TR_TADIR_INTERFACE'
      EXPORTING
        wi_tadir_pgmid    = 'R3TR'
        wi_tadir_object   = 'ENQU'
        wi_tadir_obj_name = lv_obj_name
        wi_set_genflag    = abap_true
        wi_test_modus     = abap_false
        wi_tadir_devclass = '$TMP'
      EXCEPTIONS
        OTHERS            = 1.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'migrate, error from TR_TADIR_INTERFACE' ).
    ENDIF.

    CALL FUNCTION 'DDIF_ENQU_ACTIVATE'
      EXPORTING
        name        = lcl_persistence_db=>c_lock
      EXCEPTIONS
        not_found   = 1
        put_failure = 2
        OTHERS      = 3.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'migrate, error from DDIF_ENQU_ACTIVATE' ).
    ENDIF.

  ENDMETHOD.

  METHOD table_exists.

    DATA: lv_tabname TYPE dd02l-tabname.

    SELECT SINGLE tabname FROM dd02l INTO lv_tabname
      WHERE tabname = lcl_persistence_db=>c_tabname.
    rv_exists = boolc( sy-subrc = 0 ).

  ENDMETHOD.

  METHOD table_create.

    DATA: lv_obj_name TYPE tadir-obj_name,
          ls_dd02v    TYPE dd02v,
          ls_dd09l    TYPE dd09l,
          lt_dd03p    TYPE STANDARD TABLE OF dd03p WITH DEFAULT KEY.

    FIELD-SYMBOLS: <ls_dd03p> LIKE LINE OF lt_dd03p.

    ls_dd02v-tabname    = lcl_persistence_db=>c_tabname.
    ls_dd02v-ddlanguage = gc_english.
    ls_dd02v-tabclass   = 'TRANSP'.
    ls_dd02v-ddtext     = c_text.
    ls_dd02v-contflag   = 'A'.
    ls_dd02v-exclass    = '1'.

    ls_dd09l-tabname  = lcl_persistence_db=>c_tabname.
    ls_dd09l-as4local = 'A'.
    ls_dd09l-tabkat   = '1'.
    ls_dd09l-tabart   = 'APPL1'.
    ls_dd09l-bufallow = 'N'.

    APPEND INITIAL LINE TO lt_dd03p ASSIGNING <ls_dd03p>.
    <ls_dd03p>-tabname   = lcl_persistence_db=>c_tabname.
    <ls_dd03p>-fieldname = 'TYPE'.
    <ls_dd03p>-position  = '0001'.
    <ls_dd03p>-keyflag   = 'X'.
    <ls_dd03p>-datatype  = 'CHAR'.
    <ls_dd03p>-leng      = '000012'.

    APPEND INITIAL LINE TO lt_dd03p ASSIGNING <ls_dd03p>.
    <ls_dd03p>-tabname   = lcl_persistence_db=>c_tabname.
    <ls_dd03p>-fieldname = 'VALUE'.
    <ls_dd03p>-position  = '0002'.
    <ls_dd03p>-keyflag   = 'X'.
    <ls_dd03p>-datatype  = 'CHAR'.
    <ls_dd03p>-leng      = '000012'.

    APPEND INITIAL LINE TO lt_dd03p ASSIGNING <ls_dd03p>.
    <ls_dd03p>-tabname   = lcl_persistence_db=>c_tabname.
    <ls_dd03p>-fieldname = 'DATA_STR'.
    <ls_dd03p>-position  = '0003'.
    <ls_dd03p>-datatype  = 'STRG'.

    CALL FUNCTION 'DDIF_TABL_PUT'
      EXPORTING
        name              = lcl_persistence_db=>c_tabname
        dd02v_wa          = ls_dd02v
        dd09l_wa          = ls_dd09l
      TABLES
        dd03p_tab         = lt_dd03p
      EXCEPTIONS
        tabl_not_found    = 1
        name_inconsistent = 2
        tabl_inconsistent = 3
        put_failure       = 4
        put_refused       = 5
        OTHERS            = 6.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'migrate, error from DDIF_TABL_PUT' ).
    ENDIF.

    lv_obj_name = lcl_persistence_db=>c_tabname.
    CALL FUNCTION 'TR_TADIR_INTERFACE'
      EXPORTING
        wi_tadir_pgmid    = 'R3TR'
        wi_tadir_object   = 'TABL'
        wi_tadir_obj_name = lv_obj_name
        wi_set_genflag    = abap_true
        wi_test_modus     = abap_false
        wi_tadir_devclass = '$TMP'
      EXCEPTIONS
        OTHERS            = 1.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'migrate, error from TR_TADIR_INTERFACE' ).
    ENDIF.

    CALL FUNCTION 'DDIF_TABL_ACTIVATE'
      EXPORTING
        name        = lcl_persistence_db=>c_tabname
      EXCEPTIONS
        not_found   = 1
        put_failure = 2
        OTHERS      = 3.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'migrate, error from DDIF_TABL_ACTIVATE' ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_settings DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS set_proxy_url
      IMPORTING
        iv_url TYPE string.
    METHODS set_proxy_port
      IMPORTING
        iv_port TYPE string.
    METHODS get_proxy_url
      RETURNING
        VALUE(rv_proxy_url) TYPE string.
    METHODS get_proxy_port
      RETURNING
        VALUE(rv_port) TYPE string.
    METHODS set_run_critical_tests
      IMPORTING
        iv_run TYPE abap_bool.
    METHODS
      get_run_critical_tests
        RETURNING VALUE(rv_run) TYPE abap_bool.
  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA mv_proxy_url TYPE string.
    DATA mv_proxy_port TYPE string.
    DATA mv_run_critical_tests TYPE abap_bool.


ENDCLASS.

CLASS lcl_settings IMPLEMENTATION.


  METHOD set_proxy_url.
    mv_proxy_url = iv_url.
  ENDMETHOD.

  METHOD get_proxy_url.
    rv_proxy_url = mv_proxy_url.
  ENDMETHOD.

  METHOD set_proxy_port.
    mv_proxy_port = iv_port.
  ENDMETHOD.

  METHOD get_proxy_port.
    rv_port = mv_proxy_port.
  ENDMETHOD.

  METHOD set_run_critical_tests.
    mv_run_critical_tests = iv_run.
  ENDMETHOD.

  METHOD get_run_critical_tests.
    rv_run = mv_run_critical_tests.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_persistence_settings DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS modify
      IMPORTING
        io_settings TYPE REF TO lcl_settings
      RAISING
        lcx_exception.
    METHODS read
      RETURNING
        VALUE(ro_settings) TYPE REF TO lcl_settings.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.

CLASS lcl_persistence_settings IMPLEMENTATION.


  METHOD modify.
    lcl_app=>db( )->modify(
      iv_type       = 'SETTINGS'
      iv_value      = 'PROXY_URL'
      iv_data       = io_settings->get_proxy_url( ) ).

    lcl_app=>db( )->modify(
      iv_type       = 'SETTINGS'
      iv_value      = 'PROXY_PORT'
      iv_data       = io_settings->get_proxy_port( ) ).

    lcl_app=>db( )->modify(
      iv_type       = 'SETTINGS'
      iv_value      = 'CRIT_TESTS'
      iv_data       = io_settings->get_run_critical_tests( ) ).
  ENDMETHOD.


  METHOD read.
    DATA: lv_critical_tests_as_string  TYPE string,
          lv_critical_tests_as_boolean TYPE abap_bool.

    CREATE OBJECT ro_settings.
    TRY.
        ro_settings->set_proxy_url(
          lcl_app=>db( )->read(
            iv_type  = 'SETTINGS'
            iv_value = 'PROXY_URL'
          ) ).
      CATCH lcx_not_found.
        ro_settings->set_proxy_url( '' ).
    ENDTRY.
    TRY.
        ro_settings->set_proxy_port(
          lcl_app=>db( )->read(
            iv_type  = 'SETTINGS'
            iv_value = 'PROXY_PORT'
          ) ).
      CATCH lcx_not_found.
        ro_settings->set_proxy_port( '' ).
    ENDTRY.
    TRY.
        lv_critical_tests_as_string = lcl_app=>db( )->read(
           iv_type  = 'SETTINGS'
           iv_value = 'CRIT_TESTS' ).
        lv_critical_tests_as_boolean = lv_critical_tests_as_string.
        ro_settings->set_run_critical_tests( lv_critical_tests_as_boolean ).
      CATCH lcx_not_found.
        ro_settings->set_run_critical_tests( abap_false ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.