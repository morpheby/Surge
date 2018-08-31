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

public enum MatrixAxies {
    case row
    case column
}

public protocol FlatMatrix {
    associatedtype Element
    associatedtype RowCollection: UnsafeMemoryAccessible where RowCollection.Element == Element
    associatedtype ColumnCollection: UnsafeMemoryAccessible where ColumnCollection.Element == Element

    var rowCount: Int { get }
    var columnCount: Int { get }
    var grid: [Element] { get set }

    subscript(row row: Int) -> RowCollection { get }
    subscript(column column: Int) -> ColumnCollection { get }
    subscript(row row: Int, column column: Int) -> Element { get }

    init<T: Collection, U: Collection>(_ contents: T) where T.Element == U, U.Element == Element
    init(rows: Int, columns: Int, repeatedValue: Element)
    init(rows: Int, columns: Int, grid: [Element])
}

public func matrixOp<T, U>(_ op: ([U]) -> [U], _ x: T) -> T where T: FlatMatrix, T.Element == U {
    return T(rows: x.rowCount, columns: x.columnCount, grid: op(x.grid))
}

public func matrixOp<T, U>(_ op: ([U], [U]) -> [U], _ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == U {
    precondition(x.rowCount == y.rowCount && x.columnCount == y.columnCount, "Matrix dimensions not compatible with operation")

    return T(rows: x.rowCount, columns: x.columnCount, grid: op(x.grid, y.grid))
}

public func add<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp(.+, x, y)
}

public func add<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp(.+, x, y)
}

public func sub<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp(.-, x, y)
}

public func sub<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp(.-, x, y)
}

public func mul<T>(_ alpha: Float, _ x: T) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp({ $0 * alpha }, x)
}

public func mul<T>(_ alpha: Double, _ x: T) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp({ $0 * alpha }, x)
}

public func mul<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Float {
    precondition(x.columnCount == y.rowCount, "Matrix dimensions not compatible with multiplication")

    var results = T(rows: x.rowCount, columns: y.columnCount, repeatedValue: 0.0)
    results.grid.withUnsafeMutableBufferPointer { pointer in
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(x.rowCount), Int32(y.columnCount), Int32(x.columnCount), 1.0, x.grid, Int32(x.columnCount), y.grid, Int32(y.columnCount), 0.0, pointer.baseAddress!, Int32(y.columnCount))
    }

    return results
}

public func mul<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Double {
    precondition(x.columnCount == y.rowCount, "Matrix dimensions not compatible with multiplication")

    var results = T(rows: x.rowCount, columns: y.columnCount, repeatedValue: 0.0)
    results.grid.withUnsafeMutableBufferPointer { pointer in
        cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(x.rowCount), Int32(y.columnCount), Int32(x.columnCount), 1.0, x.grid, Int32(x.columnCount), y.grid, Int32(y.columnCount), 0.0, pointer.baseAddress!, Int32(y.columnCount))
    }

    return results
}

public func elmul<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp(.*, x, y)
}

public func elmul<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp(.*, x, y)
}

public func div<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Float {
    let yInv = inv(y)
    precondition(x.columnCount == yInv.rowCount, "Matrix dimensions not compatible")
    return mul(x, yInv)
}

public func div<T>(_ x: T, _ y: T) -> T where T: FlatMatrix, T.Element == Double {
    let yInv = inv(y)
    precondition(x.columnCount == yInv.rowCount, "Matrix dimensions not compatible")
    return mul(x, yInv)
}

public func pow<T>(_ x: T, _ y: Float) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp({ pow($0, y) }, x)
}

public func pow<T>(_ x: T, _ y: Double) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp({ pow($0, y) }, x)
}

public func exp<T>(_ x: T) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp(exp, x)
}

public func exp<T>(_ x: T) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp(exp, x)
}

public func sum<T>(_ x: T, axies: MatrixAxies = .column) -> [Float] where T: FlatMatrix, T.Element == Float {

    switch axies {
    case .column:
        var result = [Float](repeating: 0.0, count: x.columnCount)
        for i in 0..<x.columnCount {
            result[i] = sum(x[column: i])
        }
        return result

    case .row:
        var result = [Float](repeating: 0.0, count: x.rowCount)
        for i in 0..<x.rowCount {
            result[i] = sum(x[row: i])
        }
        return result
    }
}

public func sum<T>(_ x: T, axies: MatrixAxies = .column) -> [Double] where T: FlatMatrix, T.Element == Double {

    switch axies {
    case .column:
        var result = [Double](repeating: 0.0, count: x.columnCount)
        for i in 0..<x.columnCount {
            result[i] = sum(x[column: i])
        }
        return result

    case .row:
        var result = [Double](repeating: 0.0, count: x.rowCount)
        for i in 0..<x.rowCount {
            result[i] = sum(x[row: i])
        }
        return result
    }
}

public func inv<T>(_ x: T) -> T where T: FlatMatrix, T.Element == Float {
    precondition(x.rowCount == x.columnCount, "Matrix must be square")

    var results = T(rows: x.rowCount, columns: x.columnCount, grid: x.grid)

    var ipiv = [__CLPK_integer](repeating: 0, count: x.rowCount * x.rowCount)
    var lwork = __CLPK_integer(x.columnCount * x.columnCount)
    var work = [CFloat](repeating: 0.0, count: Int(lwork))
    var error: __CLPK_integer = 0
    var nc = __CLPK_integer(x.columnCount)

    withUnsafeMutablePointers(&nc, &lwork, &error) { nc, lwork, error in
        withUnsafeMutableMemory(&ipiv, &work, &results.grid) { ipiv, work, grid in
            sgetrf_(nc, nc, grid.pointer, nc, ipiv.pointer, error)
            sgetri_(nc, grid.pointer, nc, ipiv.pointer, work.pointer, lwork, error)
        }
    }

    assert(error == 0, "Matrix not invertible")

    return results
}

public func inv<T>(_ x: T) -> T where T: FlatMatrix, T.Element == Double {
    precondition(x.rowCount == x.columnCount, "Matrix must be square")

    var results = T(rows: x.rowCount, columns: x.columnCount, grid: x.grid)

    var ipiv = [__CLPK_integer](repeating: 0, count: x.rowCount * x.rowCount)
    var lwork = __CLPK_integer(x.columnCount * x.columnCount)
    var work = [CDouble](repeating: 0.0, count: Int(lwork))
    var error: __CLPK_integer = 0
    var nc = __CLPK_integer(x.columnCount)

    withUnsafeMutablePointers(&nc, &lwork, &error) { nc, lwork, error in
        withUnsafeMutableMemory(&ipiv, &work, &results.grid) { ipiv, work, grid in
            dgetrf_(nc, nc, grid.pointer, nc, ipiv.pointer, error)
            dgetri_(nc, grid.pointer, nc, ipiv.pointer, work.pointer, lwork, error)
        }
    }

    assert(error == 0, "Matrix not invertible")

    return results
}

public func transpose<T>(_ x: T) -> T where T: FlatMatrix, T.Element == Float {
    var results = T(rows: x.columnCount, columns: x.rowCount, repeatedValue: 0.0)
    results.grid.withUnsafeMutableMemory { resultPtr in
        x.grid.withUnsafeMemory { xPtr in
            vDSP_mtrans(xPtr.pointer, 1, resultPtr.pointer, 1, vDSP_Length(x.columnCount), vDSP_Length(x.rowCount))
        }
    }

    return results
}

public func transpose<T>(_ x: T) -> T where T: FlatMatrix, T.Element == Double {
    var results = T(rows: x.columnCount, columns: x.rowCount, repeatedValue: 0.0)
    results.grid.withUnsafeMutableMemory { resultPtr in
        x.grid.withUnsafeMemory { xPtr in
            vDSP_mtransD(xPtr.pointer, 1, resultPtr.pointer, 1, vDSP_Length(x.columnCount), vDSP_Length(x.rowCount))
        }
    }

    return results
}

/// Computes the matrix determinant.
public func det<T>(_ x: T) -> Float? where T: FlatMatrix, T.Element == Float {
    var decomposed = T(rows: x.rowCount, columns: x.columnCount, grid: x.grid)
    var pivots = [__CLPK_integer](repeating: 0, count: min(x.rowCount, x.columnCount))
    var info = __CLPK_integer()
    var m = __CLPK_integer(x.rowCount)
    var n = __CLPK_integer(x.columnCount)
    _ = withUnsafeMutableMemory(&pivots, &decomposed.grid) { ipiv, grid in
        withUnsafeMutablePointers(&m, &n, &info) { m, n, info in
            sgetrf_(m, n, grid.pointer, m, ipiv.pointer, info)
        }
    }

    if info != 0 {
        return nil
    }

    var det = 1 as Float
    for (i, p) in zip(pivots.indices, pivots) {
        if p != i + 1 {
            det = -det * decomposed[row: i, column: i]
        } else {
            det = det * decomposed[row: i, column: i]
        }
    }
    return det
}

/// Computes the matrix determinant.
public func det<T>(_ x: T) -> Double? where T: FlatMatrix, T.Element == Double {
    var decomposed = T(rows: x.rowCount, columns: x.columnCount, grid: x.grid)
    var pivots = [__CLPK_integer](repeating: 0, count: min(x.rowCount, x.columnCount))
    var info = __CLPK_integer()
    var m = __CLPK_integer(x.rowCount)
    var n = __CLPK_integer(x.columnCount)
    _ = withUnsafeMutableMemory(&pivots, &decomposed.grid) { ipiv, grid in
        withUnsafeMutablePointers(&m, &n, &info) { m, n, info in
            dgetrf_(m, n, grid.pointer, m, ipiv.pointer, info)
        }
    }

    if info != 0 {
        return nil
    }

    var det = 1 as Double
    for (i, p) in zip(pivots.indices, pivots) {
        if p != i + 1 {
            det = -det * decomposed[row: i, column: i]
        } else {
            det = det * decomposed[row: i, column: i]
        }
    }
    return det
}

// MARK: - Operators

public func + <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Float {
    return add(lhs, rhs)
}

public func + <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Double {
    return add(lhs, rhs)
}

public func - <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Float {
    return sub(lhs, rhs)
}

public func - <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Double {
    return sub(lhs, rhs)
}

public func + <T> (lhs: T, rhs: Float) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp({ $0 + rhs }, lhs)
}

public func + <T> (lhs: T, rhs: Double) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp({ $0 + rhs }, lhs)
}

public func * <T> (lhs: Float, rhs: T) -> T where T: FlatMatrix, T.Element == Float {
    return mul(lhs, rhs)
}

public func * <T> (lhs: Double, rhs: T) -> T where T: FlatMatrix, T.Element == Double {
    return mul(lhs, rhs)
}

public func * <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Float {
    return mul(lhs, rhs)
}

public func * <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Double {
    return mul(lhs, rhs)
}

public func / <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Float {
    return div(lhs, rhs)
}

public func / <T> (lhs: T, rhs: T) -> T where T: FlatMatrix, T.Element == Double {
    return div(lhs, rhs)
}

public func / <T> (lhs: T, rhs: Float) -> T where T: FlatMatrix, T.Element == Float {
    return matrixOp({ $0 / rhs }, lhs)
}

public func / <T> (lhs: T, rhs: Double) -> T where T: FlatMatrix, T.Element == Double {
    return matrixOp({ $0 / rhs }, lhs)
}

postfix operator ′

public postfix func ′ <T> (value: T) -> T where T: FlatMatrix, T.Element == Float {
    return transpose(value)
}

public postfix func ′ <T> (value: T) -> T where T: FlatMatrix, T.Element == Double {
    return transpose(value)
}
