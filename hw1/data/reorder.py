import numpy as np
import pandas as pd

df = pd.read_csv('olympics_5.csv')

years = sorted(df.Year.value_counts().index)
country_codes = sorted(df['Country Code'].value_counts().index)
n_years = len(years)

data = {year: 0.0 for year in years},
df_by_year = pd.DataFrame(data=data, index=country_codes)
for country in country_codes:
    for year in years:
        fp_ratio = df[(df.Year == year) & (df['Country Code'] == country)].fp_ratio.values
        if len(fp_ratio) == 0:
            fp_ratio = np.nan
        df_by_year.at[country, year] = fp_ratio

df_by_year.reset_index().to_csv('olympics_series.tsv', sep='\t', index=False)