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

public struct SliceableMatrix<Element> {

    public var rowCount: Int {
        return data.rowCount
    }

    public var columnCount: Int {
        return data.columnCount
    }

    fileprivate var data: Ref

    public typealias Index = Int

    fileprivate struct Ref {
        private var actualData: ActualData

        fileprivate var rowCount: Int {
            return actualData.rowCount
        }

        fileprivate var columnCount: Int {
            return actualData.columnCount
        }

        fileprivate var roData: ActualData {
            return actualData
        }

        fileprivate var rwData: ActualData {
            mutating get {
                self.mutate()
                return actualData
            }
        }

        private mutating func mutate() {
            if !isKnownUniquelyReferenced(&self.actualData) {
                self.actualData = self.actualData.copy()
            }
        }

        init(data: [Element], rowCount: Int, columnCount: Int) {
            self.actualData = ActualData(array: data, rowCount: rowCount, columnCount: columnCount)
        }

        func index(row: Index, column: Index) -> Int {
            return self.actualData.index(row: row, column: column)
        }

        func rangeIndex(row: Index, columns columnRange: Range<Index>) -> Range<Int> {
            return self.actualData.rangeIndex(row: row, columns: columnRange)
        }
    }

    fileprivate class ActualData {
        fileprivate var array: [Element]
        fileprivate let rowCount: Int
        fileprivate let columnCount: Int

        init(array: [Element], rowCount: Int, columnCount: Int) {
            self.array = array
            self.rowCount = rowCount
            self.columnCount = columnCount
        }

        func index(row: Index, column: Index) -> Int {
            precondition(row < rowCount, "Row \(row) out of bounds of matrix with row size \(rowCount)")
            precondition(column < columnCount, "Column \(column) out of bounds of matrix with column size \(columnCount)")
            return row*columnCount+column
        }

        func rangeIndex(row: Index, columns columnRange: Range<Index>) -> Range<Int> {
            precondition(row < rowCount, "Row \(row) out of bounds of matrix with row size \(rowCount)")
            precondition(columnRange.lowerBound >= 0 && columnRange.upperBound <= columnCount, "Range \(columnRange) does not fit into \(0..<columnCount)")
            let startIndex = row * columnCount + columnRange.lowerBound
            let endIndex = row * columnCount + columnRange.upperBound
            return Range(uncheckedBounds: (startIndex, endIndex))
        }

        func copy() -> ActualData {
            return ActualData(array: self.array, rowCount: rowCount, columnCount: columnCount)
        }
    }

    public init(rowCount: Int, columnCount: Int, defaultValue: Element) {
        let data = Array(repeating: defaultValue, count: rowCount * columnCount)
        self.data = Ref(data: data, rowCount: rowCount, columnCount: columnCount)
    }

    public init(rowCount: Int, columnCount: Int, flatArray: [Element]) {
        self.data = Ref(data: flatArray, rowCount: rowCount, columnCount: columnCount)
    }

    public init<T: Collection, U: Collection>(rowMajorData: T) where T.Element == U, U.Element == Element {
        let rowCount = rowMajorData.count

        let columnCount = rowMajorData.first?.count ?? 0

        precondition(rowMajorData.reduce(true, { r, v in r && v.count == columnCount }), "Unaligned data")

        var data: [Element] = []
        data.reserveCapacity(rowCount * columnCount)
        for row in rowMajorData {
            data.append(contentsOf: row)
        }
        self.data = Ref(data: data, rowCount: rowCount, columnCount: columnCount)
    }

    public func allDataRowMajor() -> [[Element]] {
        return (0..<rowCount).map { i in Array(data.roData.array[columnCount*i..<columnCount*(i+1)]) }
    }

    public subscript(row row: Index, column column: Index) -> Element {
        get {
            return data.roData.array[data.index(row: row, column: column)]
        }
        set {
            data.rwData.array[data.index(row: row, column: column)] = newValue
        }
    }

    public subscript(_ x: Index, _ y: Index) -> Element {
        get {
            return self[row: y, column: x]
        }
        set {
            self[row: y, column: x] = newValue
        }
    }

    public subscript(row row: Index) -> RowSlice {
        get {
            return RowSlice(row: row, ref: data)
        }
    }

    public subscript(column column: Index) -> ColumnSlice {
        get {
            return ColumnSlice(column: column, ref: data)
        }
    }

    public struct RowSlice: RandomAccessCollection, ExpressibleByArrayLiteral {
        public init(arrayLiteral elements: Element...) {
            self.init(row: 0, ref: Ref(data: elements, rowCount: 1, columnCount: elements.count))
        }

        public typealias ArrayLiteralElement = Element

        fileprivate let rowIndex: Index
        fileprivate let data: Ref

        fileprivate init(row: Index, ref: Ref) {
            self.rowIndex = row
            self.data = ref
        }

        public var startIndex: Index {
            return 0
        }

        public var endIndex: Index {
            return data.columnCount
        }

        public subscript (column: Index) -> Element {
            get {
                return data.roData.array[data.index(row: rowIndex, column: column)]
            }
        }
    }

    public struct ColumnSlice: RandomAccessCollection, ExpressibleByArrayLiteral {
        public init(arrayLiteral elements: Element...) {
            self.init(column: 0, ref: Ref(data: elements, rowCount: elements.count, columnCount: 1))
        }

        public typealias ArrayLiteralElement = Element

        fileprivate let columnIndex: Index
        fileprivate let data: Ref

        fileprivate init(column: Index, ref: Ref) {
            self.columnIndex = column
            self.data = ref
        }

        public var startIndex: Index {
            return 0
        }

        public var endIndex: Index {
            return data.rowCount
        }

        public subscript (row: Index) -> Element {
            get {
                return data.roData.array[data.index(row: row, column: columnIndex)]
            }
        }

        public func index(after i: Int) -> Int {
            return i + 1
        }
    }

    public mutating func replace<R, C>(subrange: R, with: C) where R: RangeExpression, C: Collection, C.Element == Element, R.Bound == Index {
        let realRange = subrange.relative(to: self)
        data.rwData.array.replaceSubrange(realRange, with: with)
    }

    public mutating func replace<C>(row: Int, with: C) where C: Collection, C.Element == Element {
        replace(row: row, subrange: 0..., with: with)
    }

    public mutating func replace<C>(column: Int, with: C) where C: Collection, C.Element == Element {
        replace(column: column, subrange: 0..., with: with)
    }

    public mutating func replace<R, C>(row: Int, subrange: R, with: C) where R: RangeExpression, C: Collection, C.Element == Element, R.Bound == ColumnSlice.Index {
        let realRange = subrange.relative(to: self[row: row])
        let start = columnCount * row + realRange.lowerBound
        let end = columnCount * row + realRange.upperBound
        data.rwData.array.replaceSubrange(start..<end, with: with)
    }

    public mutating func replace<R, C>(column: Int, subrange: R, with: C) where R: RangeExpression, C: Collection, C.Element == Element, R.Bound == ColumnSlice.Index {
        let realRange = subrange.relative(to: self[column: column])
        for (rowIndex, value) in zip(realRange.lowerBound..<realRange.upperBound, with) {
            self[row: rowIndex, column: column] = value
        }
    }
}

extension SliceableMatrix: Collection {
    public var startIndex: Index {
        return 0
    }

    public var endIndex: Index {
        return rowCount * columnCount
    }

    public subscript (linear: Index) -> Element {
        get {
            return data.roData.array[linear]
        }
        set {
            data.rwData.array[linear] = newValue
        }
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }
}

extension SliceableMatrix: FlatMatrix {
    public var grid: [Element] {
        get { return data.roData.array }
        set { data.rwData.array = newValue }
    }

    public init(rows: Int, columns: Int, repeatedValue: Element) {
        self.init(rowCount: rows, columnCount: columns, defaultValue: repeatedValue)
    }

    public init<T: Collection, U: Collection>(_ contents: T) where T.Element == U, U.Element == Element {
        self.init(rowMajorData: contents)
    }

    public init(rows: Int, columns: Int, grid: [Element]) {
        self.init(rowCount: rows, columnCount: columns, flatArray: grid)
    }
}

extension SliceableMatrix {
    public init(row: [Element]) {
        self.init(rows: 1, columns: row.count, grid: row)
    }

    public init(column: [Element]) {
        self.init(rows: column.count, columns: 1, grid: column)
    }
}

extension SliceableMatrix: CustomStringConvertible {
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

extension SliceableMatrix: Equatable where Element: Equatable {
}

public func ==<T> (lhs: SliceableMatrix<T>, rhs: SliceableMatrix<T>) -> Bool where T: Equatable {
    return lhs.rowCount == rhs.rowCount && lhs.columnCount == rhs.columnCount && lhs.elementsEqual(rhs)
}

extension SliceableMatrix.RowSlice: Equatable where Element: Equatable {
}

public func ==<T> (lhs: SliceableMatrix<T>.RowSlice, rhs: SliceableMatrix<T>.RowSlice) -> Bool where T: Equatable {
    return lhs.elementsEqual(rhs)
}

extension SliceableMatrix.ColumnSlice: Equatable where Element: Equatable {
}

public func ==<T> (lhs: SliceableMatrix<T>.ColumnSlice, rhs: SliceableMatrix<T>.ColumnSlice) -> Bool where T: Equatable {
    return lhs.elementsEqual(rhs)
}

extension SliceableMatrix: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: (0..<self.rowCount).map { self[row: $0] }, displayStyle: .collection)
    }
}

extension SliceableMatrix.RowSlice: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: (0..<self.data.columnCount).map { self[$0] }, displayStyle: .collection)
    }
}

extension SliceableMatrix.ColumnSlice: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: (0..<self.data.rowCount).map { self[$0] }, displayStyle: .collection)
    }
}

extension SliceableMatrix: UnsafeMemoryAccessible, UnsafeMutableMemoryAccessible {
    public func withUnsafeMemory<Result>(_ action: (UnsafeMemory<Element>) throws -> Result) rethrows -> Result {
        return try Surge.withUnsafeMemory(data.roData.array, action)
    }

    public mutating func withUnsafeMutableMemory<Result>(_ action: (UnsafeMutableMemory<Element>) throws -> Result) rethrows -> Result {
        return try Surge.withUnsafeMutableMemory(&data.rwData.array, action)
    }
}

extension SliceableMatrix.RowSlice: UnsafeMemoryAccessible {
    public func withUnsafeMemory<Result>(_ action: (UnsafeMemory<Element>) throws -> Result) rethrows -> Result {
        return try Surge.withUnsafeMemory(data.roData.array[data.rangeIndex(row: rowIndex, columns: 0..<data.columnCount)], action)
    }
}

extension SliceableMatrix.ColumnSlice: UnsafeMemoryAccessible {
    public func withUnsafeMemory<Result>(_ action: (UnsafeMemory<Element>) throws -> Result) rethrows -> Result {
        return try Surge.withUnsafeMemory(data.roData.array) { memory in
            let new = UnsafeMemory(pointer: memory.pointer, stride: data.columnCount, count: data.rowCount)
            return try action(new)
        }
    }
}
