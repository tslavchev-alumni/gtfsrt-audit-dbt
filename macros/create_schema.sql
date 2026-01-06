{% macro snowflake__create_schema(relation) %}
  {#-
    We pre-create schemas in Snowflake and do not allow dbt to create them.
    This macro intentionally does nothing.
  -#}
{% do return(none) %}
{% endmacro %}
