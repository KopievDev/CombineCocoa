//
//  UICollectionView.swift
//  
//
//  Created by Иван Копиев on 15.09.2023.
//

import UIKit
import Combine

@available(iOS 13.0, *)
public extension UICollectionView {
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
    @available(iOS 13.0, *)
    func bind<Item: Publisher, Element>(
        _ cells: Item,
        _ builder: @escaping (UICollectionView, IndexPath, Element) -> UICollectionViewCell
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
    func bind<Cell: UICollectionViewCell, Item: Publisher, Element>(
        _ cells: Item,
        cellType: Cell.Type,
        _ builder: @escaping (IndexPath, Element, Cell) -> Void
    ) -> AnyCancellable where Item.Output == [Element] {
        cells.sink(receiveCompletion: { _ in }, receiveValue: items(cellType: Cell.self, builder))
    }

    func items<Element>(_ builder: @escaping (UICollectionView, IndexPath, Element) -> UICollectionViewCell) -> ([Element]) -> Void {
        let dataSource = CombineCollectionViewDataSource(builder: builder)
        return { items in dataSource.pushElements(items, to: self) }
    }

    func items<Cell: UICollectionViewCell, Element>(cellType: Cell.Type,
                                               _ builder: @escaping (IndexPath, Element, Cell) -> Void) -> ([Element]) -> Void {
        let dataSource = CombineCollectionViewDataSourceWithType(type: cellType, builder: builder)
        return { items in dataSource.pushElements(items, to: self) }
    }

}

final class CombineCollectionViewDataSource<Element>: NSObject, UICollectionViewDataSource {

    let build: (UICollectionView, IndexPath, Element) -> UICollectionViewCell
    var elements: [Element] = []

    init(builder: @escaping (UICollectionView, IndexPath, Element) -> UICollectionViewCell) {
        build = builder
        super.init()
    }

    func pushElements(_ elements: [Element], to collectionView: UICollectionView) {
        collectionView.dataSource = self
        self.elements = elements
        DispatchQueue.main.async { collectionView.reloadData() }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        elements.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        build(collectionView, indexPath, elements[indexPath.row])
    }
}

final class CombineCollectionViewDataSourceWithType<Element, Cell: UICollectionViewCell>: NSObject, UICollectionViewDataSource {

    let build: (IndexPath, Element, Cell) -> Void
    var elements: [Element] = []
    var cellType: Cell.Type

    init(type: Cell.Type, builder: @escaping (IndexPath, Element, Cell) -> Void) {
        build = builder
        cellType = type
        super.init()
    }

    func pushElements(_ elements: [Element], to collectionView: UICollectionView) {
        collectionView.dataSource = self
        self.elements = elements
        DispatchQueue.main.async { collectionView.reloadData() }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        elements.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.reuseId, for: indexPath) as? Cell else { return UICollectionViewCell() }
        build(indexPath, elements[indexPath.row], cell)
        return cell
    }
}

