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

    /**
     Example

         enum Cell { case cell(SomeData), header(String) }
         @Published var items = [Cell]()
         let collection = UICollectionView()
         private var subscriptions = Set<AnyCancellable>()

         collection.bind($items) { col, index, cells in
             switch cells {
             case .cell(let data):
             return col.dequeueCell(HistoryCell.self, index) { $0.render(model: data) }
             case .header(let data):
             return col.dequeueCell(HistoryDayCell.self, index) { $0.render(model: data) }
             }
         }.store(in: &subscriptions)
     */
    func bind<Item: Publisher, Element>(
        _ cells: Item,
        _ builder: @escaping (UITableView, IndexPath, Element) -> UITableViewCell
    ) -> AnyCancellable where Item.Output == [Element] {
        cells.sink(receiveCompletion: { _ in }, receiveValue: items(builder))
    }

    /**
     Example

         @Published var items = [String]()
         let collec = UICollectionView()
         private var subscriptions = Set<AnyCancellable>()

         collec.bind($items, cellType: SomeCell.self) { index, element, cell in
            cell.render(model: element)
         }.store(in: &subscriptions)
     */
    func bind<Cell: UITableViewCell, Item: Publisher, Element>(
        _ cells: Item,
        cellType: Cell.Type,
        _ builder: @escaping (IndexPath, Element, Cell) -> Void
    ) -> AnyCancellable where Item.Output == [Element] {
        cells.sink(receiveCompletion: { _ in }, receiveValue: items(cellType: Cell.self, builder))
    }

    func didSelectItem<Element>(
        type: Element.Type,
        completion: @escaping (Element) -> Void
    ) -> AnyCancellable {
        let delegate = CombineTableViewDelegate<Element>(completion: completion)
        self.delegate = delegate
        return delegate.didSelectItem.sink { element in completion(element) }
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

protocol Did {
    associatedtype T
    var didSelectItem: PassthroughSubject<T, Never> { get set }
}

final class CombineTableViewDataSourceWithType<Element, Cell: UITableViewCell>: NSObject, UITableViewDataSource, Did {

    typealias T = Element
    var didSelectItem: PassthroughSubject<Element, Never> = .init()

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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let dataSource = tableView.dataSource as? CombineTableViewDataSourceWithType<Element, UITableViewCell> {
            let element = dataSource.elements[indexPath.row]
            DispatchQueue.main.async { self.didSelectItem.send(element) }

        }

        if let dataSource = tableView.dataSource as? CombineTableViewDataSource<Element> {
            let element = dataSource.elements[indexPath.row]
            DispatchQueue.main.async { self.didSelectItem.send(element) }
        }
    }
}

final class CombineTableViewDelegate<Element>: NSObject, UITableViewDelegate {

    let didSelectItem = PassthroughSubject<Element, Never>()
    let completion: (Element) -> Void
    private var subscriptions: Set<AnyCancellable> = []

    init(completion: @escaping (Element) -> Void) {
        self.completion = completion
        super.init()
        didSelectItem
            .sink { self.completion($0) }
            .store(in: &subscriptions)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let dataSource = tableView.dataSource as? CombineTableViewDataSourceWithType<Element, UITableViewCell> {
            let element = dataSource.elements[indexPath.row]
            DispatchQueue.main.async { self.didSelectItem.send(element) }

        }

        if let dataSource = tableView.dataSource as? CombineTableViewDataSource<Element> {
            let element = dataSource.elements[indexPath.row]
            DispatchQueue.main.async { self.didSelectItem.send(element) }
        }
    }
}

open class BaseCell<ViewModel>: UITableViewCell {

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    open func commonInit() {
        selectionStyle = .none
    }

    open func render(viewModel: ViewModel) { }
}

open class BaseCollectionCell<ViewModel>: UICollectionViewCell {

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    open func commonInit() {
        selectionStyle = .none
    }

    open func render(viewModel: ViewModel) { }
}
