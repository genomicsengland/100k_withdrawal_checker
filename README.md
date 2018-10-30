# Daily Data Checks

## Synopsis

This set of scripts run daily checks of MI data, compares against previous checks and publishes the difference (i.e. new changes in data) to specific slack channels. The aim of this is to proactively check the clinical data according to specific criteria and notify the data quality team where action is required.

## Checks in place

  * Full withdrawal
  * 'No' to consent

## Connections

These scripts require ssh connections to the CDT MIS db copy found on `10.1.24.39`
