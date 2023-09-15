//
//  UITableView.swift
//  
//
//  Created by Иван Копиев on 15.09.2023.
//

import UIKit
import Combine
public protocol IdentifiableCell {
    static var reuseId: String { get }
}

extension IdentifiableCell {
    public static var reuseId: String { "\(self)" }
}

extension UITableViewCell: IdentifiableCell {}

extension UICollectionViewCell: IdentifiableCell {}

extension UITableViewHeaderFooterView: IdentifiableCell {}

public extension UITableView {
    /**
     Example

            @Published var items = [String]()
            let table = UITableView()
            private var subscriptions = Set<AnyCancellable>()

             $items.sink(receiveValue: table.items({ table, index, element in
                 table.dequeueCell(UITableViewCell.self, index) { cell in
                     cell.textLabel?.text = element
                 }
             })).store(in: &subscriptions)
     */
    func items<Element>(_ builder: @escaping (UITableView, IndexPath, Element) -> UITableViewCell) -> ([Element]) -> Void {
        let dataSource = CombineTableViewDataSource(builder: builder)
        return { items in
            dataSource.pushElements(items, to: self)
        }
    }
    /**
     Example

            @Published var items = [String]()
            let table = UITableView()
            private var subscriptions = Set<AnyCancellable>()

             $items.sink(receiveValue: table.items(cellType: UITableViewCell.self, { index, element, cell in
                 cell.textLabel?.text = element
             })).store(in: &subscriptions)
     */
    func items<Cell: UITableViewCell, Element>(cellType: Cell.Type,
                                               _ builder: @escaping (IndexPath, Element, Cell) -> Void) -> ([Element]) -> Void {
        let dataSource = CombineTableViewDataSourceWithType(type: cellType, builder: builder)
        return { items in
            dataSource.pushElements(items, to: self)
        }
    }

    func register<Cell: UITableViewCell>(_ type: Cell.Type) {
        register(type.self, forCellReuseIdentifier: type.reuseId)
    }

    func register<Header: UITableViewHeaderFooterView>(_ type: Header.Type) {
        register(type.self, forHeaderFooterViewReuseIdentifier: type.reuseId)
    }

    func dequeueCell<T: UITableViewCell>(_ indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseId, for: indexPath) as? T else {
            fatalError("No cell for this id: \(T.reuseId)")
        }
        return cell
    }

    func dequeueCell<T: UITableViewCell>(_ type: T.Type,
                                                _ indexPath: IndexPath,
                                                updateBlock: (T) -> Void = { _ in }) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseId, for: indexPath) as? T else {
            fatalError("No cell for this id: \(T.reuseId)")
        }
        updateBlock(cell)
        return cell
    }

    func dequeue<T: UITableViewHeaderFooterView>(_ type: T.Type,
                                                        updateBlock: (T) -> Void = { _ in }) -> T {
        guard let cell = dequeueReusableHeaderFooterView(withIdentifier: T.reuseId) as? T else {
            fatalError("No cell for this id: \(T.reuseId)")
        }
        updateBlock(cell)
        return cell
    }

}

final class CombineTableViewDataSource<Element>: NSObject, UITableViewDataSource {

    let build: (UITableView, IndexPath, Element) -> UITableViewCell
    var elements: [Element] = []

    init(builder: @escaping (UITableView, IndexPath, Element) -> UITableViewCell) {
        build = builder
        super.init()
    }

    func pushElements(_ elements: [Element], to tableView: UITableView) {
        tableView.dataSource = self
        self.elements = elements
        DispatchQueue.main.async { tableView.reloadData() }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        elements.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        build(tableView, indexPath, elements[indexPath.row])
    }
}

final class CombineTableViewDataSourceWithType<Element, Cell: UITableViewCell>: NSObject, UITableViewDataSource {

    let build: (IndexPath, Element, Cell) -> Void
    var elements: [Element] = []
    var cellType: Cell.Type

    init(type: Cell.Type, builder: @escaping (IndexPath, Element, Cell) -> Void) {
        build = builder
        cellType = type
        super.init()
    }

    func pushElements(_ elements: [Element], to tableView: UITableView) {
        tableView.dataSource = self
        self.elements = elements
        DispatchQueue.main.async { tableView.reloadData() }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        elements.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellType.reuseId, for: indexPath) as? Cell else { return UITableViewCell() }
        build(indexPath, elements[indexPath.row], cell)
        return cell
    }
}
