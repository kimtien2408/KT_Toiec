using System.IO.Compression;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;

namespace backend.Services;

public sealed class ExamDocxParser
{
    private static readonly XNamespace Word =
        "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

    private static readonly Regex QuestionTag = new(
        @"^\[Q:\s*(\d+)\]\s*(.*)$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex PartTag = new(
        @"^\[PART:\s*(\d+)\]$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex ChoiceTag = new(
        @"^(?<prefix>.*?)\[(?<letter>[A-D])\]\s*(?<text>.*)$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex KeyTag = new(
        @"^\[(?:KEY|ANSWER|CORRECT|ĐÁP ÁN|DAP AN)\s*[:=]\s*([A-D])\]$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex AnswerPrefix = new(
        @"^\s*(?:\[\s*(?:x|✓|✔|\*|correct)\s*\]|[✓✔*+])\s*$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex AnswerAtStart = new(
        @"^\s*(?:\[\s*(?:x|✓|✔|\*|correct)\s*\]|[✓✔*+])\s*",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    public const long MaximumFileSize = 20 * 1024 * 1024;
    private const long MaximumDocumentXmlSize = 32 * 1024 * 1024;

    public ExamDocxParseResult Parse(Stream stream)
    {
        var errors = new List<string>();
        var questions = new List<ParsedExamQuestion>();
        var passages = new List<ParsedExamPassage>();
        var questionNumbers = new HashSet<int>();
        ParsedQuestionBuilder? currentQuestion = null;
        ParsedExamPassage? currentPassage = null;
        var currentPart = 0;

        try
        {
            using var archive = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: true);
            var documentEntry = archive.GetEntry("word/document.xml");
            if (documentEntry is null)
            {
                return ExamDocxParseResult.Failure(
                    ["Tệp không phải DOCX hợp lệ: thiếu word/document.xml."]);
            }
            if (documentEntry.Length > MaximumDocumentXmlSize)
            {
                return ExamDocxParseResult.Failure(
                    ["Nội dung DOCX vượt quá giới hạn xử lý an toàn."]);
            }

            XDocument document;
            using (var entryStream = documentEntry.Open())
            using (var reader = XmlReader.Create(entryStream, new XmlReaderSettings
            {
                DtdProcessing = DtdProcessing.Prohibit,
                XmlResolver = null,
                MaxCharactersInDocument = MaximumDocumentXmlSize,
            }))
            {
                document = XDocument.Load(reader);
            }

            var body = document.Root?.Element(Word + "body");
            if (body is null)
            {
                return ExamDocxParseResult.Failure(
                    ["Tệp DOCX không có phần nội dung bài thi."]);
            }

            foreach (var node in body.Elements())
            {
                if (node.Name == Word + "tbl")
                {
                    var passageContent = ReadTableText(node);
                    if (!string.IsNullOrWhiteSpace(passageContent))
                    {
                        currentPassage = new ParsedExamPassage(currentPart, passageContent);
                        passages.Add(currentPassage);
                    }
                    continue;
                }

                if (node.Name != Word + "p")
                {
                    continue;
                }

                var text = ReadParagraphText(node).Trim();
                if (text.Length == 0)
                {
                    continue;
                }

                var partMatch = PartTag.Match(text);
                if (partMatch.Success)
                {
                    FinalizeQuestion(currentQuestion, questions, errors);
                    currentQuestion = null;
                    if (!int.TryParse(partMatch.Groups[1].Value, out currentPart))
                    {
                        errors.Add($"Tag Part không hợp lệ: {text}.");
                        continue;
                    }
                    currentPassage = null;
                    if (currentPart is not (5 or 6 or 7))
                    {
                        errors.Add($"Phần thi không hợp lệ: {text}.");
                    }
                    continue;
                }

                var questionMatch = QuestionTag.Match(text);
                if (questionMatch.Success)
                {
                    FinalizeQuestion(currentQuestion, questions, errors);
                    if (!int.TryParse(questionMatch.Groups[1].Value, out var number))
                    {
                        errors.Add($"Số câu không hợp lệ trong tag: {text}.");
                        continue;
                    }
                    if (!questionNumbers.Add(number))
                    {
                        errors.Add($"Câu {number}: số thứ tự bị trùng.");
                    }

                    currentQuestion = new ParsedQuestionBuilder(
                        number,
                        currentPart,
                        questionMatch.Groups[2].Value.Trim(),
                        currentPart is 6 or 7 ? currentPassage : null);
                    continue;
                }

                if (currentQuestion is null)
                {
                    continue;
                }

                var choiceMatch = ChoiceTag.Match(text);
                if (choiceMatch.Success)
                {
                    var answerIndex = char.ToUpperInvariant(
                        choiceMatch.Groups["letter"].Value[0]) - 'A';
                    var answerText = choiceMatch.Groups["text"].Value.Trim();
                    var prefixMatch = AnswerAtStart.Match(answerText);
                    var visualMarker = HasFullTextFormatting(
                        node,
                        choiceMatch,
                        prefixMatch.Success ? prefixMatch.Length : 0);
                    var prefixMarker = AnswerPrefix.IsMatch(
                        choiceMatch.Groups["prefix"].Value);
                    var contentPrefixMarker = prefixMatch.Success;
                    answerText = AnswerAtStart.Replace(answerText, string.Empty, 1).Trim();

                    if (answerText.Length == 0)
                    {
                        errors.Add($"Câu {currentQuestion.Number}: đáp án {(char)('A' + answerIndex)} đang trống.");
                    }
                    if (!currentQuestion.Choices.TryAdd(answerIndex, answerText))
                    {
                        errors.Add($"Câu {currentQuestion.Number}: đáp án {(char)('A' + answerIndex)} bị lặp.");
                    }
                    if (visualMarker || prefixMarker || contentPrefixMarker)
                    {
                        currentQuestion.MarkedAnswers.Add(answerIndex);
                    }
                    continue;
                }

                var keyMatch = KeyTag.Match(text);
                if (keyMatch.Success)
                {
                    currentQuestion.MarkedAnswers.Add(
                        char.ToUpperInvariant(keyMatch.Groups[1].Value[0]) - 'A');
                    continue;
                }

                if (text.StartsWith("[EXPLANATION:", StringComparison.OrdinalIgnoreCase))
                {
                    var explanation = text["[EXPLANATION:".Length..].Trim();
                    if (explanation.EndsWith(']'))
                    {
                        explanation = explanation[..^1].Trim();
                    }
                    currentQuestion.Hint = explanation;
                }
            }

            FinalizeQuestion(currentQuestion, questions, errors);
        }
        catch (InvalidDataException)
        {
            return ExamDocxParseResult.Failure(
                ["Không đọc được tệp DOCX. Hãy kiểm tra tệp Word và thử lưu lại dưới dạng .docx."]);
        }
        catch (XmlException)
        {
            return ExamDocxParseResult.Failure(
                ["Cấu trúc XML bên trong DOCX bị lỗi. Hãy mở và lưu lại tài liệu bằng Word."]);
        }
        catch (IOException)
        {
            return ExamDocxParseResult.Failure(
                ["Không thể đọc đầy đủ tệp DOCX. Hãy kiểm tra tệp và thử lại."]);
        }

        ValidateExam(questions, errors);
        return errors.Count > 0
            ? ExamDocxParseResult.Failure(errors)
            : ExamDocxParseResult.Success(questions, passages);
    }

    private static void FinalizeQuestion(
        ParsedQuestionBuilder? question,
        ICollection<ParsedExamQuestion> questions,
        ICollection<string> errors)
    {
        if (question is null)
        {
            return;
        }

        foreach (var letter in Enumerable.Range(0, 4))
        {
            if (!question.Choices.ContainsKey(letter))
            {
                errors.Add($"Câu {question.Number}: thiếu đáp án {(char)('A' + letter)}.");
            }
        }

        if (question.MarkedAnswers.Count != 1)
        {
            var detail = question.MarkedAnswers.Count == 0
                ? "chưa đánh dấu đáp án đúng"
                : $"có {question.MarkedAnswers.Count} đáp án được đánh dấu là đúng";
            errors.Add($"Câu {question.Number}: {detail}; cần đúng một đáp án.");
        }

        if (question.Part is not (5 or 6 or 7))
        {
            errors.Add($"Câu {question.Number}: thiếu tag [PART: 5], [PART: 6] hoặc [PART: 7].");
            return;
        }

        if (question.Prompt.Length == 0)
        {
            errors.Add($"Câu {question.Number}: thiếu nội dung câu hỏi.");
        }
        if (question.Part is 6 or 7 && question.Passage is null)
        {
            errors.Add($"Câu {question.Number}: Part {question.Part} chưa gắn với đoạn đọc.");
        }

        questions.Add(new ParsedExamQuestion(
            question.Number,
            question.Part,
            question.Prompt,
            Enumerable.Range(0, 4)
                .Select(index => question.Choices.GetValueOrDefault(index) ?? string.Empty)
                .ToArray(),
            question.MarkedAnswers.Count == 1 ? question.MarkedAnswers.Single() : -1,
            question.Hint,
            question.Passage));
    }

    private static void ValidateExam(
        IReadOnlyList<ParsedExamQuestion> questions,
        ICollection<string> errors)
    {
        if (questions.Count == 0)
        {
            errors.Add("Không tìm thấy câu hỏi nào trong tài liệu.");
        }

        var maximumPartCounts = new Dictionary<int, int>
        {
            [5] = 30,
            [6] = 16,
            [7] = 54,
        };
        foreach (var (part, maximumCount) in maximumPartCounts)
        {
            var actualCount = questions.Count(question => question.Part == part);
            if (actualCount > maximumCount)
            {
                errors.Add(
                    $"Part {part} tối đa có {maximumCount} câu; hiện tìm thấy {actualCount} câu.");
            }
        }

        var orderedQuestions = questions.OrderBy(question => question.Number).ToList();
        for (var index = 1; index < orderedQuestions.Count; index++)
        {
            if (orderedQuestions[index].Number <= orderedQuestions[index - 1].Number)
            {
                errors.Add(
                    $"Số câu phải tăng dần; câu {orderedQuestions[index].Number} bị sai thứ tự.");
            }
        }
    }

    private static bool HasFullTextFormatting(
        XElement paragraph,
        Match choiceMatch,
        int optionPrefixLength)
    {
        var optionStart = choiceMatch.Groups["text"].Index + optionPrefixLength;
        var optionLength = choiceMatch.Groups["text"].Length - optionPrefixLength;
        if (optionLength == 0)
        {
            return false;
        }

        var runSegments = paragraph.Descendants(Word + "r")
            .Select(run => new
            {
                Text = string.Concat(run.Descendants(Word + "t").Select(element => element.Value)),
                Properties = run.Element(Word + "rPr"),
            })
            .Where(run => run.Text.Length > 0)
            .ToList();

        var offset = 0;
        var coveredCharacters = 0;
        var allBold = true;
        var allHighlighted = true;
        var allUnderlined = true;
        var allColored = true;

        foreach (var run in runSegments)
        {
            var runStart = offset;
            var runEnd = offset + run.Text.Length;
            offset = runEnd;
            var overlapStart = Math.Max(runStart, optionStart);
            var overlapEnd = Math.Min(runEnd, optionStart + optionLength);
            if (overlapStart >= overlapEnd)
            {
                continue;
            }

            var selectedText = run.Text[(overlapStart - runStart)..(overlapEnd - runStart)];
            var relevantLength = selectedText.Count(character => !char.IsWhiteSpace(character));
            if (relevantLength == 0)
            {
                continue;
            }

            coveredCharacters += relevantLength;
            var properties = run.Properties;
            var bold = IsEnabled(properties?.Element(Word + "b"))
                || IsEnabled(properties?.Element(Word + "bCs"));
            var highlighted = properties?.Element(Word + "highlight") is { } highlight
                && !string.Equals(
                    (string?)highlight.Attribute(Word + "val"),
                    "none",
                    StringComparison.OrdinalIgnoreCase);
            var underline = properties?.Element(Word + "u") is { } underlined
                && !string.Equals(
                    (string?)underlined.Attribute(Word + "val"),
                    "none",
                    StringComparison.OrdinalIgnoreCase);
            var color = (string?)properties?.Element(Word + "color")?.Attribute(Word + "val");
            var colored = color is not null
                && !string.Equals(color, "auto", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(color, "000000", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(color, "FFFFFF", StringComparison.OrdinalIgnoreCase);

            allBold &= bold;
            allHighlighted &= highlighted;
            allUnderlined &= underline;
            allColored &= colored;
        }

        return coveredCharacters > 0
            && (allBold || allHighlighted || allUnderlined || allColored);
    }

    private static bool IsEnabled(XElement? property)
    {
        if (property is null)
        {
            return false;
        }

        var value = (string?)property.Attribute(Word + "val");
        return value is null
            || (value != "0" && !string.Equals(value, "false", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(value, "off", StringComparison.OrdinalIgnoreCase));
    }

    private static string ReadParagraphText(XElement paragraph)
    {
        return string.Concat(paragraph.DescendantNodes().Select(node => node switch
        {
            XElement element when element.Name == Word + "t" => element.Value,
            XElement element when element.Name == Word + "tab" => "\t",
            XElement element when element.Name == Word + "br" => " ",
            _ => string.Empty,
        }));
    }

    private static string ReadTableText(XElement table)
    {
        var rows = table.Elements(Word + "tr")
            .Select(row => string.Join(
                " | ",
                row.Elements(Word + "tc")
                    .Select(ReadCellText)
                    .Where(text => !string.IsNullOrWhiteSpace(text))))
            .Where(row => !string.IsNullOrWhiteSpace(row));
        return string.Join(Environment.NewLine, rows);
    }

    private static string ReadCellText(XElement cell)
    {
        return string.Join(
            Environment.NewLine,
            cell.Elements().Select(element => element.Name switch
            {
                var name when name == Word + "p" => ReadParagraphText(element),
                var name when name == Word + "tbl" => ReadTableText(element),
                _ => string.Empty,
            }).Where(text => !string.IsNullOrWhiteSpace(text)));
    }

    private sealed class ParsedQuestionBuilder(
        int number,
        int part,
        string prompt,
        ParsedExamPassage? passage)
    {
        public int Number { get; } = number;
        public int Part { get; } = part;
        public string Prompt { get; } = prompt;
        public ParsedExamPassage? Passage { get; } = passage;
        public Dictionary<int, string> Choices { get; } = [];
        public HashSet<int> MarkedAnswers { get; } = [];
        public string? Hint { get; set; }
    }
}

public sealed record ParsedExamPassage(int Part, string Content);

public sealed record ParsedExamQuestion(
    int Number,
    int Part,
    string Prompt,
    IReadOnlyList<string> Choices,
    int CorrectAnswerIndex,
    string? Hint,
    ParsedExamPassage? Passage);

public sealed record ExamDocxParseResult(
    bool IsValid,
    IReadOnlyList<string> Errors,
    IReadOnlyList<ParsedExamQuestion> Questions,
    IReadOnlyList<ParsedExamPassage> Passages)
{
    public static ExamDocxParseResult Failure(IReadOnlyList<string> errors) =>
        new(false, errors, [], []);

    public static ExamDocxParseResult Success(
        IReadOnlyList<ParsedExamQuestion> questions,
        IReadOnlyList<ParsedExamPassage> passages) =>
        new(true, [], questions, passages);
}
