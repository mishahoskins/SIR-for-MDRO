
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
 * Notes:        Program pulls all CRE/MDRO cases and links them to a 'pretend' NC where we create demographic breakdowns to mimic NC. Then we use this population estimate to create logistic reg. for all
 *				 variables that are deemed important in CRE transmission that we can assign to a population value and apply that regression at the row level to create a probability of infection for each "individual"
 *				 in the state. Then we total those up for our "expected" value to create an estimated SIR. 
 *				 Model design: https://www.cdc.gov/nhsn/2022rebaseline/sir-guide.pdf	
 *
 *
 *				 By assigning a value independently to each demographic or risk factor. I suspect our outcomes will bias toward the NULL becuase we know each of these factors compound each other and separating them
 *				 into independent categories randomizes each risk factor categorization making one person less likely to have multiple risk factors. 
 *	
 *				 For example, in NC, black/aa populations may be more likely to be in a high SVI area thus compounding risk. In this model, SVI is independent of race and assigned randomly. Thus, the probability of
 *				 being black/aa AND in an SVI high geopgraphical area is less likely than in the real world. By biasing toward the NULL, I think it is ok to assume the logistic model underestimates the statistical significance 
 *				 of each factor (except maybe age). By underestimating the impact the model may not be as powerful and any statistically significant conclusions will be more likely to be true in real world application while  
 *				 non-statistically significant conclusions could be underestimated. 
 *	
 *	
 *				 TLDR; this is a very conservative model. 
 *	
 *	
 *------------------------------------------------------------------------------
 */

/*Clear results from prior code*/
dm 'odsresults; clear';


libname SASdata 'T:\HAI\Code library\Epi curve example\SASData'; /*SAS datasets location*/

/*Create dataset to represent NC population - case number and assign race, age, gender, HCE, svi, and rurality based on percentage of the population. Essentially a 'pretend' NC with the same demograpic breakdown  */

data denoms_expanded;
call streaminit(123); /* Better random generator than ranuni */

do identifier = 1 to (10835491-368); /*state pop - number of infections*/

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

/*HCE_yn: binary healthcare experience randomized: 
Data estimate from here: https://www.cdc.gov/nchs/fastats/hospital.htm and https://ftp.cdc.gov/pub/Health_Statistics/NCHS/NHIS/SHS/2018_SHS_Table_P-10.pdf
Assuming NC follows the national trend lets err on the conservative side and say 7.9% of the 'pretend' population has a HCE experience*/
HCE_yn = rand("bernoulli", 0.079); /* ~10% high vulnerability */

output;
end;
run;

/*Check to make sure the numbers and the percentages are representative of each population group (should reflect NC)*/
proc freq data=denoms_expanded; tables age_group race*svi /*rurality svi  gender eth HCE_yn*/ /norow nocol nocum;run;


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

proc freq data= case_import;tables HCE / norow nocol nopercent;run;

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

/*Healthcare experience*/

	case when HCE in ('No', 'Unknown') then 0 
		 when HCE in ('') then .

	else 1 end as HCE_yn,

	case when CLASSIFICATION_CLASSIFICATION in ('Confirmed') then 1 else 0 end as case_flag

from case_import 
;
alter table cases_analysis 
		drop race_new; /*keep numeric only*/
quit;

/*Join population file to our case file for a comprehensive file of a 'pretend' NC with real cases*/
proc sql;
create table population_file as
select
	
	identifier, age_group, rurality, svi, race, eth, gender, HCE_yn,

	case when identifier not in (.) then 0 else 1 end as case_flag

from denoms_expanded

union select

	identifier, age_group, rurality, svi, race, eth, gender, HCE_yn,

	case_flag

from cases_analysis

;

quit;


/*Create a logistic reg. model using key variables... in a perfect world we're using statistically significant values only, but for example's sake we'll keep everything*/
proc logistic data=population_file descending outmodel=model_logit;

	class age_group (param=ref ref='0') race (param=ref ref='0')  rurality (param=ref ref='0') 
		  svi (param=ref ref='0') eth (param=ref ref='0') gender (param=ref ref='0') HCE_yn (param=ref ref='0');
	model case_flag = age_group race rurality svi gender eth HCE_yn / expb;

run;


/*KEY PIECE: Now we're going to use our model we created and apply it to each row with "score." The logistic formula logit (prob) = intercept + B1Var1 + B2Var2 + BnVarn will be applied to each row. Where B is the parameter and Var is the presence or category of the variable*/
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

	 P_1 as prob_total "Total CRE Predicted" format 10.2,
	 case_flag as mdro_total "Total CRE Observed" format 10.0,

		( mdro_total /  prob_total) as MDRO_infecratio "CRE Infection Ratio" format 10.2,
		(STDERR(calculated MDRO_infecratio)) as std_err "Standard error" 



from population_score
;
quit;

/*Now sum all of our probabilities to create an 'expected' value and sum all the case_flags to create our 'actual' value. Then we can take the standard error to create our confidence intervals and display a nice "SIR" estimate table*/
proc sql;
create table test_sir_mdro_CI as
select
	
	 sum (prob_total) as prob_total_2 "Total CRE Predicted" format 10.2,
	 sum (mdro_total) as mdro_total_2 "Total CRE Observed" format 10.0,
		(calculated mdro_total_2 / calculated prob_total_2) as MDRO_infecratio_2 "CRE Infection Ratio" format 10.2,

		/*Since standard error is the same for each valuation, we'll just take the "max" one so we just have a single value. Could do min or select a specific one, just need 1 std error for CI calc.*/
		max(std_err) as std_err_calc "Standard error",
		(calculated MDRO_infecratio_2 - (1.96*(calculated std_err_calc))) as lCL "Lower confidence limit" format 10.2,
		(calculated MDRO_infecratio_2 + (1.96*(calculated std_err_calc))) as uCL "Upper confidence limit" format 10.2,

		/*Add interpretation*/
	case when calculated MDRO_infecratio_2 GE 1 and 1 < calculated lCL then "Worse than expected"
		 when calculated MDRO_infecratio_2 GE 1 and calculated uCL < 1 then "Better than expected"
		 	else "Same as expected" end as interp "Interpretion for 2024"

from test_sir_mdro
;
	alter table test_sir_mdro_CI drop std_err_calc;
quit;



proc print data=test_sir_mdro_CI noobs label;run;
