@echo off

call darklua process -c ".\.darklua.json" ".\src\arch_test\main.lua" ".\OUTPUT\temp.out.luau"
(
  echo --!nocheck
  echo --!nolint
  echo --# selene: allow(multiple_statements, unused_variable, undefined_variable, roblox_manual_fromscale_or_fromoffset, if_same_then_else, manual_table_clone, empty_if, parenthese_conditions, constant_table_comparison, shadowing, must_use, roblox_suspicious_udim2_new^)
  echo ---@diagnostic disable
  echo.
) > ".\OUTPUT\out.luau"
type ".\OUTPUT\temp.out.luau" >> ".\OUTPUT\out.luau"

call darklua minify --column-span 200 ".\OUTPUT\out.luau" ".\OUTPUT\out.min.luau"


@echo Files created successfully in 'OUTPUT\'.

rem EOF