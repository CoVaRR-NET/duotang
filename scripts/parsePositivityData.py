import pandas as pd

# Read Table 1 and Table 2 from CSV files
newDataTable= pd.read_csv('./data_needed/CanPositivityData_new.csv')
cumulativeDataTable = pd.read_csv('./data_needed/CanPositivityData.csv')

# Convert 'date' columns to datetime format for accurate comparison
cumulativeDataTable['date'] = pd.to_datetime(cumulativeDataTable['date'])
newDataTable['date'] = pd.to_datetime(newDataTable['date'])

newDataTable = newDataTable[newDataTable['virus'] == 'SARS-CoV-2']

# Merge tables to identify matching rows
merged = cumulativeDataTable.reset_index().merge(
    newDataTable,
    left_on=['prname', 'date', 'reporting_year'],
    right_on=['province', 'date', 'year'],
    suffixes=('_cumulativeDataTable', '_newDataTable')
).set_index('index')

# Update 'numtests_weekly' and 'percentpositivity_weekly' in Table 1 with matching rows from Table 2
mask_numtests = cumulativeDataTable.loc[merged.index, 'numtests_weekly'].values != merged['tests'].values
cumulativeDataTable.loc[merged.index[mask_numtests], 'numtests_weekly'] = merged.loc[mask_numtests, 'tests']
cumulativeDataTable.loc[merged.index[mask_numtests], 'update'] = "updated" # Set 'update' to 1 for rows where 'numtests_weekly' was updated

mask_percentpositive = cumulativeDataTable.loc[merged.index, 'percentpositivity_weekly'].values != merged['percentpositive'].values
cumulativeDataTable.loc[merged.index[mask_percentpositive], 'percentpositivity_weekly'] = merged.loc[mask_percentpositive, 'percentpositive']
cumulativeDataTable.loc[merged.index[mask_percentpositive], 'update'] = "updated"  # Set 'update' to 1 for rows where 'percentpositivity_weekly' was updated


# Identify rows in Table 2 where 'date' does not exist in Table 1 and add them to Table 1
new_rows = newDataTable[~newDataTable['date'].isin(cumulativeDataTable['date'])]
new_rows['update'] = "new"
# Append new rows to Table 1, renaming columns to match
cumulativeDataTable = pd.concat([
    cumulativeDataTable,
    new_rows.rename(columns={
        'province': 'prname',
        'tests': 'numtests_weekly',
        'percentpositive': 'percentpositivity_weekly',
        'week' : 'reporting_week',
        'year' : 'reporting_year',
        'update' : 'update'
    })
], ignore_index=True)

cumulativeDataTable = cumulativeDataTable.drop(columns=["region","weekorder","virus","detections"])

cumulativeDataTable.to_csv('./data_needed/CanPositivityData.csv', index=False)