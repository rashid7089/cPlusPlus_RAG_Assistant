WITH RankedAnswers AS (
    SELECT 
        q.Id AS QuestionId,
        q.Title AS QuestionTitle,
        q.Body AS QuestionBody,
        q.Score AS QuestionScore,
        a.Id AS AnswerId,
        a.Body AS AnswerBody,
        a.Score AS AnswerScore,
        ROW_NUMBER() OVER (PARTITION BY q.Id ORDER BY a.Score DESC) AS AnswerRank
    FROM Posts q
    INNER JOIN Posts a ON q.Id = a.ParentId
    WHERE q.Tags LIKE '%<c++>%'  -- Filters specifically for the C++ tag
      AND q.PostTypeId = 1       -- 1 = Questions
      AND a.PostTypeId = 2       -- 2 = Answers
      AND q.Score > 5            -- Filter out low-quality questions
      AND a.Score > 5            -- Filter out low-quality answers
)
SELECT TOP 1000
    QuestionId,
    QuestionTitle,
    QuestionBody,
    QuestionScore,
    AnswerId,
    AnswerBody,
    AnswerScore
FROM RankedAnswers
WHERE AnswerRank = 1
ORDER BY QuestionScore DESC;