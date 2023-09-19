*"* local class implementation for public class
*"* use this source file for the implementation part of
*"* local helper classes

DEFINE escape_json.
  " => 7.31
*  &2 = escape( val = &1 format = cl_abap_format=>e_json_string ).

  lcl_util=>_escape( EXPORTING in = &1 IMPORTING out = &2 ).

* <= 7.31 (not full scope of escaping is supported)
*  &2 = &1.
*
**  replace all occurrences of regex `[\\"]` in &1 with `\\$0`. <-- this is slower than 2 plain replaces
*  REPLACE ALL OCCURRENCES OF '\' IN &2 WITH '\\'.
*  REPLACE ALL OCCURRENCES OF '"' IN &2 WITH '\"'.
*
*  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf          IN &2 WITH '\r\n'.
*  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline        IN &2 WITH '\n'.
*  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN &2 WITH '\t'.
END-OF-DEFINITION.

DEFINE is_compressable.
  IF mv_compress EQ abap_false.
    &3 = abap_false.
  ELSEIF mv_extended IS INITIAL.
    &3 = abap_true.
  ELSE.
    &3 = is_compressable( type_descr = &1 name = &2 ).
  ENDIF.
END-OF-DEFINITION.

DEFINE dump_type.
  IF mv_extended IS INITIAL.
    dump_type_int &1 &2 &3 &4.
  ELSE.
    &3 = dump_type( data = &1 type_descr = &2 convexit = &4 ).
  ENDIF.
END-OF-DEFINITION.

DEFINE xstring_to_string_int.
  IF mv_hex_as_base64 IS INITIAL.
    MOVE &1 TO &2.
  ELSE.
    &2 = xstring_to_string( &1 ).
  ENDIF.
END-OF-DEFINITION.

DEFINE string_to_xstring_int.
  IF mv_hex_as_base64 IS INITIAL.
    MOVE &1 TO &2.
  ELSE.
    string_to_xstring( EXPORTING in = &1 CHANGING out = &2 ).
  ENDIF.
END-OF-DEFINITION.

DEFINE format_list_output.
  IF mv_format_output EQ abap_true AND &2 IS NOT INITIAL.
    CONCATENATE ',' lv_indent INTO lv_lb.
    CONCATENATE LINES OF &2 INTO &4 SEPARATED BY lv_lb.
    CONCATENATE &1 lv_indent &4 indent &3 INTO &4.
  ELSE.
    CONCATENATE LINES OF &2 INTO &4 SEPARATED BY ','.
    CONCATENATE &1 &4 &3 INTO &4.
  ENDIF.
END-OF-DEFINITION. " format_list_output

DEFINE dump_type_int.

  IF &4 IS NOT INITIAL AND &1 IS NOT INITIAL.
    TRY.
      CALL FUNCTION &4
        EXPORTING
          input    = &1
        IMPORTING
          output   = &3
        EXCEPTIONS
          OTHERS   = 1.
      IF sy-subrc IS INITIAL.
        CONCATENATE '"' &3 '"' INTO &3.
      ENDIF.
    CATCH cx_root ##CATCH_ALL ##NO_HANDLER.
    ENDTRY.
  ELSE.
    CASE &2->type_kind.
        WHEN mc_typekind_utclong.
          IF &1 IS INITIAL.
            &3 = mv_initial_ts.
          ELSE.
            lv_helper = &1.
            CONCATENATE '"' lv_helper(10) 'T' lv_helper+11(16) 'Z"' INTO &3.
          ENDIF.
        WHEN cl_abap_typedescr=>typekind_float OR cl_abap_typedescr=>typekind_int OR cl_abap_typedescr=>typekind_int1 OR
             cl_abap_typedescr=>typekind_int2 OR cl_abap_typedescr=>typekind_packed OR mc_typekind_int8.
        IF &2->type_kind EQ cl_abap_typedescr=>typekind_packed AND mv_ts_as_iso8601 EQ c_bool-true AND
          ( &2->absolute_name  EQ '\TYPE=TIMESTAMP' OR &2->absolute_name EQ '\TYPE=TIMESTAMPL' ).
          IF &1 IS INITIAL.
            &3 = mv_initial_ts.
          ELSE.
            lv_helper = &1.
            IF &2->absolute_name EQ '\TYPE=TIMESTAMP'.
              CONCATENATE '"' lv_helper(4) '-' lv_helper+4(2) '-' lv_helper+6(2) 'T' lv_helper+8(2) ':' lv_helper+10(2) ':' lv_helper+12(2) 'Z"' INTO &3.
            ELSE. "IF &2->absolute_name EQ '\TYPE=TIMESTAMPL'
              CONCATENATE '"' lv_helper(4) '-' lv_helper+4(2) '-' lv_helper+6(2) 'T' lv_helper+8(2) ':' lv_helper+10(2) ':' lv_helper+12(2) '.' lv_helper+15(7) 'Z"'  INTO &3.
            ENDIF.
          ENDIF.
        ELSEIF &1 IS INITIAL.
          &3 = `0`.
        ELSE.
          &3 = &1.
          IF &1 LT 0.
            IF &2->type_kind <> cl_abap_typedescr=>typekind_float. "float: sign is already at the beginning
              SHIFT &3 RIGHT CIRCULAR.
            ENDIF.
          ELSE.
            CONDENSE &3.
          ENDIF.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_num.
        IF mv_numc_as_string EQ abap_true.
          IF &1 IS INITIAL.
            &3 = `""`.
          ELSE.
            CONCATENATE '"' &1 '"' INTO &3.
          ENDIF.
        ELSE.
          &3 = &1.
          SHIFT &3 LEFT DELETING LEADING ' 0'.
          IF &3 IS INITIAL.
            &3 = `0`.
          ENDIF.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_string OR cl_abap_typedescr=>typekind_csequence OR cl_abap_typedescr=>typekind_clike.
        IF &1 IS INITIAL.
          &3 = `""`.
        ELSEIF &2->absolute_name EQ mc_json_type.
          &3 = &1.
        ELSE.
          escape_json &1 &3.
          CONCATENATE '"' &3 '"' INTO &3.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_xstring OR cl_abap_typedescr=>typekind_hex.
        IF &1 IS INITIAL.
          &3 = `""`.
        ELSE.
          xstring_to_string_int &1 &3.
          CONCATENATE '"' &3 '"' INTO &3.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_char.
        IF &2->output_length EQ 1 AND mv_bool_types CS &2->absolute_name.
          IF &1 EQ c_bool-true.
            &3 = `true`  ##NO_TEXT.
          ELSEIF &1 IS INITIAL AND mv_bool_3state CS &2->absolute_name.
            &3 = `null`.                                    "#EC NOTEXT
          ELSE.
            &3 = `false`.                                   "#EC NOTEXT
          ENDIF.
        ELSEIF &1 IS INITIAL.
          &3 = `""`.
        ELSE.
          escape_json &1 &3.
          CONCATENATE '"' &3 '"' INTO &3.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_date.
        IF &1 IS INITIAL.
          &3 = mv_initial_date.
        ELSE.
          CONCATENATE '"' &1(4) '-' &1+4(2) '-' &1+6(2) '"' INTO &3.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_time.
        IF &1 IS INITIAL.
          &3 = mv_initial_time.
        ELSE.
          CONCATENATE '"' &1(2) ':' &1+2(2) ':' &1+4(2) '"' INTO &3.
        ENDIF.
      WHEN 'k'. " cl_abap_typedescr=>typekind_enum
        &3 = &1.
        CONCATENATE '"' &3 '"' INTO &3.
      WHEN OTHERS.
        IF &1 IS INITIAL.
          &3 = `null`.                                      "#EC NOTEXT
        ELSE.
          &3 = &1.
        ENDIF.
    ENDCASE.
  ENDIF.

END-OF-DEFINITION.

DEFINE format_name.
  CASE &2.
    WHEN pretty_mode-camel_case.
      &3 = pretty_name( &1 ).
    WHEN pretty_mode-extended.
      &3 = pretty_name_ex( &1 ).
    WHEN pretty_mode-user_low_case.
      READ TABLE mt_name_mappings WITH TABLE KEY abap = &1 ASSIGNING <cache>. "#EC WARNOK
      IF sy-subrc IS INITIAL.
        &3 = <cache>-json.
      ELSE.
        &3 = &1.
        TRANSLATE &3 TO LOWER CASE.
      ENDIF.
    WHEN pretty_mode-user.
      READ TABLE mt_name_mappings WITH TABLE KEY abap = &1 ASSIGNING <cache>. "#EC WARNOK
      IF sy-subrc IS INITIAL.
        &3 = <cache>-json.
      ELSE.
        &3 = &1.
      ENDIF.
    WHEN pretty_mode-low_case.
      &3 = &1.
      TRANSLATE &3 TO LOWER CASE.
    WHEN OTHERS.
      &3 = &1.
  ENDCASE.
END-OF-DEFINITION.

DEFINE restore_reference.
  CREATE DATA data TYPE HANDLE &1.
  ASSIGN data->* TO <data>.
  restore_type( EXPORTING json = json length = length type_descr = &1 CHANGING offset = offset data = <data> ).
END-OF-DEFINITION.

DEFINE throw_error.
  RAISE EXCEPTION TYPE cx_sy_move_cast_error.
END-OF-DEFINITION.

DEFINE while_offset_cs.

*  >= 7.02 alternative
  offset = find_any_not_of( val = json sub = &1 off = offset )  ##NO_TEXT.
  IF offset EQ -1.
    offset = length.
  ENDIF.
*  >= 7.02

* < 7.02
*  WHILE offset < length.
*    FIND FIRST OCCURRENCE OF json+offset(1) IN &1.
*    IF sy-subrc IS NOT INITIAL.
*      EXIT.
*    ENDIF.
*    offset = offset + 1.
*  ENDWHILE.
* < 7.02

END-OF-DEFINITION.

DEFINE while_offset_not_cs.

*  >= 7.02 alternative
  offset = find_any_of( val = &2 sub = &1 off = offset ).
  IF offset EQ -1.
    offset = length.
  ENDIF.
*  >= 7.02

* < 7.02
*  WHILE offset < length.
*    FIND FIRST OCCURRENCE OF &2+offset(1) IN &1.
*    IF sy-subrc IS INITIAL.
*      EXIT.
*    ENDIF.
*    offset = offset + 1.
*  ENDWHILE.
* < 7.02

END-OF-DEFINITION.

DEFINE eat_white.
  while_offset_cs sv_white_space.
  IF offset GE length.
    throw_error.
  ENDIF.
END-OF-DEFINITION.

DEFINE eat_name.

  IF json+offset(1) NE '"'.
    throw_error.
  ENDIF.

  offset = mark = offset + 1.
  IF mark < length AND json+mark(1) EQ '"'.
    CLEAR &1.
  ELSE.
    FIND FIRST OCCURRENCE OF '"' IN SECTION OFFSET offset OF json MATCH OFFSET offset.
    IF sy-subrc IS NOT INITIAL.
      throw_error.
    ENDIF.
    pos = offset - 1.
    IF json+pos(1) EQ '\'. " escaped quotes inside -> fallback on advanced processing
      lcl_util=>read_string( EXPORTING json = json mark = mark CHANGING text = &1 offset = offset ).
    ELSE.
      match = offset - mark.
      &1 = json+mark(match).
    ENDIF.
  ENDIF.
  offset = offset + 1.

END-OF-DEFINITION.

DEFINE eat_number.
  mark   = offset.
  while_offset_cs '0123456789+-eE.'.
  match = offset - mark.
  &1 = json+mark(match).
END-OF-DEFINITION.

DEFINE eat_bool.
  mark   = offset.
  while_offset_cs 'aeflnrstu'.
  match = offset - mark.
  IF json+mark(match) EQ 'true'  ##NO_TEXT.
    &1 = c_bool-true.
  ELSEIF json+mark(match) EQ 'false'  ##NO_TEXT.
    IF type_descr IS BOUND AND mv_bool_3state CS type_descr->absolute_name.
      &1 = c_tribool-false.
    ELSE.
      &1 = c_bool-false.
    ENDIF.
  ELSEIF json+mark(match) EQ 'null'  ##NO_TEXT.
    CLEAR &1.
  ENDIF.
END-OF-DEFINITION.

DEFINE eat_char.
  IF offset < length AND json+offset(1) EQ &1.
    offset = offset + 1.
  ELSE.
    throw_error.
  ENDIF.
END-OF-DEFINITION.
