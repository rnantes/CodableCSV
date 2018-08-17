import XCTest
@testable import CSV

/// Tests generic and edge cases from a CSV reader perspective.
final class CSVReaderTests: XCTestCase {
    /// List of all tests to run through SPM.
    static let allTests = [
        ("testEmpty", testEmpty),
        ("testSingleValue", testSingleValue),
        ("testGeneric", testGeneric),
        ("testInvalidFieldCount", testInvalidFieldCount),
        ("testQuotedFields", testQuotedFields)
    ]
    
    /// Tests the correct parsing of an empty CSV.
    func testEmpty() {
        let parsed: CSVReader.ParsingResult
        do {
            parsed = try CSVReader.parse(string: "", configuration: .init())
        } catch let error {
            return XCTFail("An empty CSV file couldn't be read. Returned error:\n\(error)")
        }
        XCTAssertNil(parsed.headers)
        XCTAssertTrue(parsed.rows.isEmpty)
    }
    
    /// Tests the correct parsing of a single value CSV.
    func testSingleValue() {
        let input = [["Marine-Anaïs"]]
        
        let delimiters: CSV.Delimiter.Pair = (.comma, .lineFeed)
        let configuration = CSV.Configuration(fieldDelimiter: delimiters.field, rowDelimiter: delimiters.row, headerStrategy: .none, trimStrategy: .none)
        
        let parsed = CSVReader.parse(input, configuration: configuration)
        XCTAssertNil(parsed.headers)
        XCTAssertEqual(parsed.rows, input)
    }
    
    /// Tests a small generic CSV.
    ///
    /// The test data will be tested with no headers and given headers.
    func testGeneric() {
        for rowDel in [.lineFeed, .carriageReturn, .carriageReturnLineFeed] as [CSV.Delimiter.Row] {
            for fieldDel in [.comma, .semicolon, .tab] as [CSV.Delimiter.Field] {
                let inputs: [(CSV.Configuration, [[String]])] = [
                    (.init(fieldDelimiter: fieldDel, rowDelimiter: rowDel, headerStrategy: .none), TestData.Arrays.genericNoHeader),
                    (.init(fieldDelimiter: fieldDel, rowDelimiter: rowDel, headerStrategy: .firstLine), TestData.Arrays.genericHeader)
                ]
                
                for (config, input) in inputs {
                    let parsed = CSVReader.parse(input, configuration: config, delimiters: (fieldDel, rowDel))
                    
                    switch config.strategies.header {
                    case .none:
                        XCTAssertNil(parsed.headers)
                        XCTAssertEqual(input.count, parsed.rows.count)
                        XCTAssertEqual(input, parsed.rows)
                    case .firstLine:
                        XCTAssertNotNil(parsed.headers)
                        XCTAssertEqual(input.first!, parsed.headers!)
                        
                        var inputRows = input
                        inputRows.removeFirst()
                        XCTAssertEqual(inputRows.count, parsed.rows.count)
                        XCTAssertEqual(inputRows, parsed.rows)
                    case .unknown:
                        XCTFail("No test for unknown header strategy.")
                    }
                }
            }
        }
    }
    
    /// Tests a set of edge cases data.
    func testEdgeCases() {
        let input = TestData.Arrays.edgeCases
        
        for rowDel in [.lineFeed, .carriageReturn, .carriageReturnLineFeed] as [CSV.Delimiter.Row] {
            for fieldDel in [.comma, .semicolon, .tab] as [CSV.Delimiter.Field] {
                let config = CSV.Configuration(fieldDelimiter: fieldDel, rowDelimiter: rowDel, headerStrategy: .none)
                let parsed = CSVReader.parse(input, configuration: config, delimiters: (fieldDel, rowDel))
                
                XCTAssertNil(parsed.headers)
                print(parsed.rows)
            }
        }
    }
    
    /// Tests a small generic with some fields quoted.
    /// - note: This test will randomly generate quoted fields from an unquoted set of data.
    func testQuotedFields() {
        let input = TestData.Arrays.genericHeader
        let quotedInput = input.mappingRandomFields(count: 5) {
            guard !$0.hasPrefix("\"") else { return $0 }
            
            var field = $0
            field.insert("\"", at: field.startIndex)
            field.append("\"")
            return field
        }
        
        for rowDel in [.lineFeed, .carriageReturn, .carriageReturnLineFeed] as [CSV.Delimiter.Row] {
            for fieldDel in [.comma, .semicolon, .tab] as [CSV.Delimiter.Field] {
                let configuration = CSV.Configuration(fieldDelimiter: fieldDel, rowDelimiter: rowDel, headerStrategy: .firstLine)
                let parsed = CSVReader.parse(quotedInput, configuration: configuration, delimiters: (fieldDel, rowDel))
                
                XCTAssertNotNil(parsed.headers)
                XCTAssertEqual(input.first!, parsed.headers!)
                
                var inputRows = input
                inputRows.removeFirst()
                XCTAssertEqual(inputRows.count, parsed.rows.count)
                XCTAssertEqual(inputRows, parsed.rows)
            }
        }
    }
    
    /// Tests an invalid CSV input, which should lead to an error throw.
    /// - note: This test randomly generates invalid data every time is run.
    func testInvalidFieldCount() {
        for rowDel in [.lineFeed, .carriageReturn, .carriageReturnLineFeed] as [CSV.Delimiter.Row] {
            for fieldDel in [.comma, .semicolon, .tab] as [CSV.Delimiter.Field] {
                let input = TestData.Arrays.genericNoHeader.removingRandomFields(count: 2)
                let inputString: String = input.toCSV(delimiters: (fieldDel, rowDel))
                
                let configuration = CSV.Configuration(fieldDelimiter: fieldDel, rowDelimiter: rowDel, headerStrategy: .none, trimStrategy: .none)
                
                do {
                    let _ = try CSVReader.parse(string: inputString, configuration: configuration)
                    XCTFail("\nThe CSVReader should have flagged the input as invalid.")
                } catch let error as CSVReader.Error {
                    guard case .invalidInput(_) = error else {
                        return XCTFail("\nUnexpected CSVReader.Error:\n\(error)")
                    }
                } catch let error {
                    XCTFail("\nOnly CSVReader.Error shall be thrown. Instead the following error was received:\n\(error)")
                }
            }
        }
    }
}

extension CSVReader {
    /// Parses the test data format into a String and make `CSVReader` to parse it.
    fileprivate static func parse(_ testData: [[String]], configuration: CSV.Configuration, delimiters: CSV.Delimiter.Pair = (.comma, .lineFeed)) -> CSVReader.ParsingResult {
        let inputString: String = testData.toCSV(delimiters: delimiters)
        
        do {
            return try CSVReader.parse(string: inputString, configuration: configuration)
        } catch let error {
            XCTFail("The test data couldn't be parsed with error:\n\(error)")
            fatalError()
        }
    }
}
