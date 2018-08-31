// Copyright © 2014-2018 the Surge contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Accelerate

public struct Matrix<Scalar> where Scalar: FloatingPoint, Scalar: ExpressibleByFloatLiteral {
    public let rows: Int
    public let columns: Int
    public var grid: [Scalar]

    public init(rows: Int, columns: Int, repeatedValue: Scalar) {
        self.rows = rows
        self.columns = columns

        self.grid = [Scalar](repeating: repeatedValue, count: rows * columns)
    }

    public init<T: Collection, U: Collection>(_ contents: T) where T.Element == U, U.Element == Scalar {
        self.init(rows: contents.count, columns: contents.first!.count, repeatedValue: 0.0)

        for (i, row) in contents.enumerated() {
            precondition(row.count == columns, "All rows should have the same number of columns")
            grid.replaceSubrange(i*columns ..< (i + 1)*columns, with: row)
        }
    }

    public init(row: [Scalar]) {
        self.init(rows: 1, columns: row.count, grid: row)
    }

    public init(column: [Scalar]) {
        self.init(rows: column.count, columns: 1, grid: column)
    }

    public init(rows: Int, columns: Int, grid: [Scalar]) {
        precondition(grid.count == rows * columns)

        self.rows = rows
        self.columns = columns

        self.grid = grid
    }

    public subscript(row row: Int, column column: Int) -> Scalar {
        get {
            assert(indexIsValidForRow(row, column: column))
            return grid[(row * columns) + column]
        }

        set {
            assert(indexIsValidForRow(row, column: column))
            grid[(row * columns) + column] = newValue
        }
    }

    public subscript(row row: Int) -> [Scalar] {
        get {
            assert(row < rows)
            let startIndex = row * columns
            let endIndex = row * columns + columns
            return Array(grid[startIndex..<endIndex])
        }

        set {
            assert(row < rows)
            assert(newValue.count == columns)
            let startIndex = row * columns
            let endIndex = row * columns + columns
            grid.replaceSubrange(startIndex..<endIndex, with: newValue)
        }
    }

    public subscript(column column: Int) -> [Scalar] {
        get {
            var result = [Scalar](repeating: 0.0, count: rows)
            for i in 0..<rows {
                let index = i * columns + column
                result[i] = self.grid[index]
            }
            return result
        }

        set {
            assert(column < columns)
            assert(newValue.count == rows)
            for i in 0..<rows {
                let index = i * columns + column
                grid[index] = newValue[i]
            }
        }
    }

    private func indexIsValidForRow(_ row: Int, column: Int) -> Bool {
        return row >= 0 && row < rows && column >= 0 && column < columns
    }
}

extension Matrix: Equatable where Element: Equatable {
}

public func ==<T> (lhs: Matrix<T>, rhs: Matrix<T>) -> Bool where T: Equatable {
    return lhs.rowCount == rhs.rowCount && lhs.columnCount == rhs.columnCount && lhs.grid.elementsEqual(rhs.grid)
}

extension Matrix: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: (0..<self.rowCount).map { self[row: $0] }, displayStyle: .collection)
    }
}

// MARK: - FlatMatrix

extension Matrix: FlatMatrix {
    public typealias Element = Scalar
    public var rowCount: Int { return rows }
    public var columnCount: Int { return columns }

    public typealias RowCollection = [Scalar]
    public typealias ColumnCollection = [Scalar]
}

// MARK: - Printable

extension Matrix: CustomStringConvertible {
    public var description: String {
        var description = ""

        for i in 0..<rowCount {
            let contents = (0..<columnCount).map({ "\(self[row: i, column: $0])" }).joined(separator: "\t")

            switch (i, rowCount) {
            case (0, 1):
                description += "(\t\(contents)\t)"
            case (0, _):
                description += "⎛\t\(contents)\t⎞"
            case (rowCount - 1, _):
                description += "⎝\t\(contents)\t⎠"
            default:
                description += "⎜\t\(contents)\t⎥"
            }

            description += "\n"
        }

        return description
    }
}
