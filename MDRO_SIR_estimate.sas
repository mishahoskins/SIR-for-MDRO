
/*
 *------------------------------------------------------------------------------
 * Program Name:  mdro_sir_estimate
 * Author:        Mikhail Hoskins
 * Date Created:  07/23/2025
 * Date Modified: 08/19/2025
 * Description:   Apply NHSN's SIR model to MDROs in NC. 
 *				  
 *
 * Inputs:       recordssas.sas7bdat 
 * Output:       .
 * Notes:        Program pulls all CRE/MDRO cases and links them to a 'pretend' NC where we create demographic breakdowns to mimic NC. 
 *					
 *				 Model design: https://www.cdc.gov/nhsn/2022rebaseline/sir-guide.pdf	
 *
 *------------------------------------------------------------------------------
 */

/*Clear results from prior code*/
dm 'odsresults; clear';


libname SASdata 'T:\HAI\Code library\Epi curve example\SASData'; /*SAS datasets location*/

/*Create dataset to represent NC population - case number and assign race, age, gender, HCE, svi, and rurality based on percentage of the population. Essentially a 'pretend' NC with the same demograpic breakdown  */

data denoms_expanded;
call streaminit(123); /* Better random generator than ranuni */

do identifier = 1 to (10835491-368);

/* Age group weighted assignment */
rand_age = rand("uniform");
if rand_age < 0.212 then age_group = 0; /*Age 0-17*/
else if 0.212 <= rand_age < 0.303 then age_group = 1; /*Age 18-24*/
else if 0.303 <= rand_age < 0.618 then age_group = 2; /*Age 25-49*/
else if 0.618 <= rand_age < 0.806 then age_group = 3; /*Age 50-64*/
else age_group = 4; /*Age 65+*/

/* Rurality weighted assignment */
if rand("uniform") < 0.337 then rurality = 1;
else rurality = 0;

/* SVI — randomly assign 0 or 1 for now */
svi = rand("bernoulli", 0.104); /* ~10% high vulnerability */

/*Race weighted assignment */
rand_race = rand("uniform");
if rand_race < 0.698 then race = 0; /*White*/
else if 0.698 <= rand_race < 0.919 then race = 1;/*Black/African American*/
else if 0.919 <= rand_race < 0.957 then race = 2; /*Asian*//*Native Hawaiian/Pacific Islander*/
else if 0.957 <= rand_race < 0.984 then race = 3;/*Other/two or more races*/
else  race = 4;/*American Indian/Alaska Native*/

/*Hispanic weighted assignment*/
rand_eth = rand("uniform");
if rand_eth <0.886 then eth = 0; /*non-Hispanic*/
else eth = 1; /*Hispanic*/

/*Gender weighted assignment */

rand_sex = rand("uniform");
if rand_sex < 0.489 then gender= 0; /*female*/
else gender=1;


output;
end;
run;

/*Check to make sure the numbers and the percentages are representative of each population group (should reflect NC)*/
proc freq data=denoms_expanded; tables age_group rurality svi race gender eth/norow nocol nocum;run;


/*Import case file and define rurality and svi*/
 
data case_import;
set SASdata.recordssas;

	density=.;

	if owning_jd= "Alamance County"
	or owning_jd= "Buncombe County"
	or owning_jd= "Cabarrus County"
	or owning_jd= "Catawba County"
	or owning_jd= "Cumberland County"
	or owning_jd= "Davidson County"
	or owning_jd= "Durham County"
	or owning_jd= "Forsyth County"
	or owning_jd= "Gaston County"
	or owning_jd= "Guilford County"
	or owning_jd= "Henderson County"
	or owning_jd= "Iredell County"
	or owning_jd= "Johnston County"
	or owning_jd= "Lincoln County"
	or owning_jd= "Mecklenburg County"
	or owning_jd= "New Hanover County"
	or owning_jd= "Onslow County"
	or owning_jd= "Orange County"
	or owning_jd= "Pitt County"
	or owning_jd= "Rowan County"
	or owning_jd= "Union County"
	or owning_jd= "Wake County"

	then density=0; /*not rural*/

	else density=1; /*rural*/

	/*SVI
		1= GE than 0.80
		0= LT than 0.80
	*/
		svi=.;

	if owning_jd= 'Lenoir County'
	or owning_jd= 'Robeson County'
	or owning_jd= 'Scotland County'
	or owning_jd= 'Greene County'
	or owning_jd= 'Halifax County'
	or owning_jd= 'Warren County'
	or owning_jd= 'Richmond County'
	or owning_jd= 'Vance County'
	or owning_jd= 'Bertie County'
	or owning_jd= 'Sampson County'
	or owning_jd= 'Anson County'
	or owning_jd= 'Wayne County'
	or owning_jd= 'Edgecombe County'
	or owning_jd= 'Wilson County'
	or owning_jd= 'Duplin County'
	or owning_jd= 'Columbus County'
	or owning_jd= 'Hertford County'
	or owning_jd= 'Cumberland County'
	or owning_jd= 'Swain County'
	or owning_jd= 'Hyde County'

	then svi=1; /*hi svi*/

	else svi=0; /*low svi*/
	
	where year in (2024);

run;
proc print data= case_import (obs=10);run;

/*Rename and keep only variables we are analysing in numerc format*/
proc sql;
create table cases_analysis as
select



	input(CASE_ID,best.) as identifier,
/*Age groups*/
	case when 0 LE AGE LT 18 then 0 /*0-17*/
		 when 18 LE age LT 25 then 1 /*18-24*/
		 when 25 LE age LT 50 then 2 /*25-49*/
		 when 50 LE age LT 65 then 3 /*50-64*/
		 when age GE 65 then 4 /*65+*/

		 else . end as age_group,

/*Rurality*/

		 density as rurality,

/*SVI*/
		 svi,

	case
			when (RACE1 = 'Other' or RACE2 ne '' or RACE3 ne '' or RACE4 ne '' or RACE5 ne '' or RACE6 ne '')  then 'Other'
			when RACE1='Asian' then 'Asian/NH/PI'
			when RACE1='Native Hawaiian or Pacific Islander' then 'Asian/NH/PI'
				else RACE1

		end as race_new,

/*Make race numeric, group unknown and missing*/
	case when calculated race_new in ('Other') then 3
		 when calculated race_new in ('Asian/NH/PI') then 2
		 when calculated race_new in ('American Indian Alaskan Native') then 4
		 when calculated race_new in ('White') then 0
		 when calculated race_new in ('Black or African American') then 1

		 else . end as race,

/*Ethnicity*/
	case when HISPANIC in ('No') then 0 
		 when HISPANIC in ('Yes') then 1 

		 else . end as eth,

/*Gender*/

	case when GENDER in ('Female') then 0 
		 when GENDER in ('Male') then 1
		  
		 else . end as gender,

	case when CLASSIFICATION_CLASSIFICATION in ('Confirmed') then 1 else 0 end as case_flag

from case_import 
;
alter table cases_analysis 
		drop race_new; /*keep numeric only*/
quit;


proc freq data=cases_analysis; tables eth /norow nocol nocum;run;



/*Join population file to our case file for a comprehensive file of a 'pretend' NC with real cases*/
proc sql;
create table population_file as
select
	
	identifier, age_group, rurality, svi, race, eth, gender,

	case when identifier not in (.) then 0 else 1 end as case_flag

from denoms_expanded

union select

	identifier, age_group, rurality, svi, race, eth, gender, case_flag

from cases_analysis

;

quit;


/*Create a logistic reg. model using key variables... in a perfect world we're using statistically significant values only, but for example's sake we'll keep everything*/
proc logistic data=population_file descending outmodel=model_logit;

	class age_group (param=ref ref='0') race (param=ref ref='0')  rurality (param=ref ref='0')  svi (param=ref ref='0') eth (param=ref ref='0') gender (param=ref ref='0');
	model case_flag = age_group rurality svi race gender eth / expb;

run;


/*KEY PIECE: Now we're going to use our model we created and apply it to each row with "score." The logistic formula ?????????? (??p) = ?? + ??1??1 + ??2??2 + ? + ??n??n will be applied to each row.*/
proc logistic inmodel=model_logit;

	score data=population_file out=population_score  ;

run;



/* Now we have a 10 million + table and each row or pretend individual has a probability of having a CRE. Now keep/create 4 things:

	i.	probabilities
	ii. whether or not they have a CRE
	iii. create a ratio of actual:probability for each person
	iv. standard error
*/
 
proc sql;
create table test_sir_mdro as
select

	 P_1 as prob_total "Total MDROs Predicted" format 10.2,
	 case_flag as mdro_total "Total MDROs Observed" format 10.0,

		( mdro_total /  prob_total) as MDRO_infecratio "MDRO Infection Ratio" format 10.2,
		(STDERR(calculated MDRO_infecratio)) as std_err "Standard error" 



from population_score
;
quit;

/*Now sum all of our probabilities to create an 'expected' value and sum all the case_flags to create our 'actual' value. Then we can take the standard error to create our confidence intervals and display a nice "SIR" estimate table*/
proc sql;
create table test_sir_mdro_CI as
select
	
	 sum (prob_total) as prob_total_2 "Total MDROs Predicted" format 10.2,
	 sum (mdro_total) as mdro_total_2 "Total MDROs Observed" format 10.0,
		(calculated mdro_total_2 / calculated prob_total_2) as MDRO_infecratio_2 "MDRO Infection Ratio" format 10.2,

		/*Since standard error is the same for each valuation, we'll just take the "max" one so we just have a single value. Could do min or select a specific one, just need 1 std error for CI calc.*/
		max(std_err) as std_err_calc "Standard error",
		(calculated MDRO_infecratio_2 - (1.96*(calculated std_err_calc))) as lCL "Lower confidence limit" format 10.2,
		(calculated MDRO_infecratio_2 + (1.96*(calculated std_err_calc))) as uCL "Upper confidence limit" format 10.2

from test_sir_mdro
;
	alter table test_sir_mdro_CI drop std_err_calc;
quit;



proc print data=test_sir_mdro_CI noobs label;run;
