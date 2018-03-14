WITH CTE_CONCEPTS AS (
	SELECT OUTCOME_OF_INTEREST_CONCEPT_ID, OUTCOME_OF_INTEREST_CONCEPT_NAME, PERSON_COUNT_RC, PERSON_COUNT_DC, USER_INCLUDED
	FROM #NC_SUMMARY
	WHERE PERSON_COUNT_RC >= 1000
	AND DESCENDANT_PMID_COUNT = 0
	AND EXACT_PMID_COUNT = 0
	AND PARENT_PMID_COUNT = 0
	AND ANCESTOR_PMID_COUNT = 0
	AND INDICATION = 0
	{@outcomeOfInterest=='condition'}?{AND TOO_BROAD = 0}
	AND DRUG_INDUCED = 0
	{@outcomeOfInterest=='condition'}?{AND PREGNANCY = 0}
	AND SPLICER = 0
	AND FAERS = 0
	AND USER_EXCLUDED = 0
),
conceptSetConcepts AS (
	-- Concepts that are part of the concept set definition that are "EXCLUDED = N, DECENDANTS = Y or N"
	select DISTINCT concept_id
	from @vocabulary.CONCEPT
	where concept_id in (
		SELECT OUTCOME_OF_INTEREST_CONCEPT_ID FROM CTE_CONCEPTS
	)
	and invalid_reason is null
),
conceptSetDescendants AS (
	select distinct ancestor_concept_id, descendant_concept_id concept_id
	from @vocabulary.concept_ancestor
	where ancestor_concept_id in (
		SELECT OUTCOME_OF_INTEREST_CONCEPT_ID FROM CTE_CONCEPTS
	)
	and ancestor_concept_id != descendant_concept_id -- Exclude the selected ancestor itself
),
conceptSetAnalysis AS (
	SELECT
		a.concept_id original_concept_id
		, c1.concept_name original_concept_name
		, b.ancestor_concept_id
		, c3.concept_name ancestor_concept_name
		, b.concept_id subsumed_concept_id
		, c2.concept_name subsumed_concept_name
	FROM conceptSetConcepts a
		LEFT JOIN conceptSetDescendants b ON a.concept_id = b.concept_id
		LEFT JOIN @vocabulary.concept c1 ON a.concept_id = c1.concept_id
		LEFT JOIN @vocabulary.concept c2 ON b.concept_id = c2.concept_id
		LEFT JOIN @vocabulary.concept c3 ON b.ancestor_concept_id = c3.concept_id
),
conceptSetOptimized AS (
	SELECT
		original_concept_id concept_id
		, original_concept_name concept_name
	FROM conceptSetAnalysis
	WHERE subsumed_concept_id is null
),
conceptSetRemoved AS (
	SELECT DISTINCT
		subsumed_concept_id concept_id
		, subsumed_concept_name concept_name
	FROM conceptSetAnalysis
	WHERE subsumed_concept_id is not null
)
SELECT *
INTO #NC_SUMMARY_OPTIMIZED
FROM CTE_CONCEPTS c
WHERE c.OUTCOME_OF_INTEREST_CONCEPT_ID IN (
	SELECT CONCEPT_ID
	FROM conceptSetOptimized
)
ORDER BY PERSON_COUNT_DC DESC, OUTCOME_OF_INTEREST_CONCEPT_NAME;
