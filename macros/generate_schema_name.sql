{% macro generate_schema_name(custom_schema_name, node) -%}
  {#-
    In this project, we want schemas to be explicit and stable.
    dbt Cloud sometimes appends suffixes to schemas (especially for seeds).
    This macro forces dbt to use exactly the provided schema (or the target schema).
  -#}
  {{ (custom_schema_name if custom_schema_name is not none else target.schema) | trim }}
{%- endmacro %}
