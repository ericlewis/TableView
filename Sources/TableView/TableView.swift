import SwiftUI
import CoreData

class TableDataSource: UITableViewDiffableDataSource<String, NSManagedObjectID> {
  var sectionTitles: [String]? = nil
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    sectionIndexTitles(for: tableView)?[section]
  }
  
  override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    sectionTitles
  }
}

class FetchedTableViewController<T: NSManagedObject, Content: View>: UITableView, NSFetchedResultsControllerDelegate {
  var fetchRequest: NSFetchRequest<T>
  var context: NSManagedObjectContext
  var sectionNameKeyPath: String?
  var rootView: (T) -> Content
  
  var initialized = false
  
  lazy var diffDataSource = TableDataSource(tableView: self) { tv, indexPath, i in
    let cell = UITableViewCell()
    
    let view = UIHostingController(rootView: self.rootView(self.context.object(with: i) as! T)).view
    view?.backgroundColor = .clear
    cell.contentView.addSubview(view!)
    
    view!.preservesSuperviewLayoutMargins = true
    view!.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view!.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
      view!.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
      view!.topAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.topAnchor),
      view!.bottomAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.bottomAnchor),
    ])
    
    return cell
  }
  
  lazy var frc: NSFetchedResultsController<T> = {
    let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                managedObjectContext: context,
                                                sectionNameKeyPath: sectionNameKeyPath,
                                                cacheName: nil)
    controller.delegate = self
    
    return controller
  }()
  
  init(_ fetchRequest: NSFetchRequest<T>, context: NSManagedObjectContext, style: UITableView.Style = .plain, sectionNameKeyPath: String? = nil, rootView: @escaping (T) -> Content) {
    self.context = context
    self.fetchRequest = fetchRequest
    self.rootView = rootView
    
    super.init(frame: .zero, style: style)
  }
  
  func initialize() {
    if initialized {
      return
    }
    
    register(UITableViewCell.self, forCellReuseIdentifier: "t")
    
    do {
      try frc.performFetch()
    } catch {
      print(error)
    }
    
    initialized = true
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    initialize()
  }
  
  typealias Snapshot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
  typealias DataSource = UICollectionViewDiffableDataSourceReference
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
    diffDataSource.sectionTitles = sectionNameKeyPath == nil ? nil : snapshot.sectionIdentifiers as? [String]
    diffDataSource.apply(snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>,
                         animatingDifferences: true)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

struct TableView<T: NSManagedObject, Content: View>: UIViewRepresentable {
  @Binding var fetchRequest: NSFetchRequest<T>
  
  let sectionNameKeyPath: String?
  let content: (T) -> Content
  let tapped: ((T) -> Void)?
  let style: UITableView.Style

  init(fetchRequest: Binding<NSFetchRequest<T>>, style: UITableView.Style = .plain, sectionNameKeyPath: String? = nil,  tapped: ((T) -> Void)? = nil, @ViewBuilder content: @escaping (T) -> Content) {
    _fetchRequest = fetchRequest
    self.content = content
    self.tapped = tapped
    self.style = style
    self.sectionNameKeyPath = sectionNameKeyPath
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  func makeUIView(context: Context) -> FetchedTableViewController<T, Content> {
    let view = FetchedTableViewController(fetchRequest,
                                          context: context.environment.managedObjectContext,
                                          style: style,
                                          sectionNameKeyPath: sectionNameKeyPath,
                                          rootView: content)
    view.delegate = context.coordinator
    
    return view
  }
  
  func updateUIView(_ uiViewController: FetchedTableViewController<T, Content>, context: Context) {
    uiViewController.sectionNameKeyPath = sectionNameKeyPath
    uiViewController.rootView = content
  }
  
  class Coordinator: NSObject, UITableViewDelegate {
    var parent: TableView
    
    init(_ parent: TableView) {
      self.parent = parent
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
      let view = tableView as! FetchedTableViewController<T, Content>
      parent.tapped?(view.frc.object(at: indexPath))
      tableView.deselectRow(at: indexPath, animated: true)
    }
  }
}
