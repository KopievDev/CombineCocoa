# CombineCocoa

Binding collection

```swift 
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
```

```swift 
    @Published var items = [String]()
    let collec = UICollectionView()
    private var subscriptions = Set<AnyCancellable>()

    collec.bind($items, cellType: SomeCell.self) { index, element, cell in
        cell.render(model: element)
    }.store(in: &subscriptions)
```
