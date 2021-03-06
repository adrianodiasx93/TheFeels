//
//  UserTweetsViewController.swift
//  User
//
//  Created by Adriano Dias on 29/09/20.
//

import UIKit
import Common
import RxSwift
import RxCocoa
import RxDataSources

public class UserTweetsViewController: UIViewController {

    // MARK: Properties
    private lazy var userTweetsView = UserTweetsView()
    private lazy var loadingView = EvaluatingView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
    private let bag = DisposeBag()
    private let viewModel: UserTweetsViewModeling
    private let loadSubject = BehaviorRelay(value: ())

    // MARK: Init
    public init(viewModel: UserTweetsViewModeling) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Life cycle
    public override func loadView() {
        view = userTweetsView
        userTweetsView.delegate = self
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        bind()
    }
}

// MARK: UI
extension UserTweetsViewController {

    private func setupUI() {
        title = L10n.UserTweetsViewController.title
        navigationController?.asTranslucent()
        navigationController?.setNavigationBarHidden(false, animated: true)
        userTweetsView.tableView.isHidden = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: loadingView)
    }

    private func setSubViewsVisibility(isDataSourceEmpty: Bool) {
        UIView.animate(withDuration: 0.1) {
            self.userTweetsView.lblEmpty.isHidden = !isDataSourceEmpty
            self.userTweetsView.tableView.isHidden = isDataSourceEmpty
        }
    }

    func setAnimation(isLoading: Bool) {
        loadingView.animationView.alpha = isLoading ? 1 : 0
        if isLoading, !loadingView.animationView.isAnimationPlaying {
            loadingView.animationView.play(completion: nil)
        } else if !isLoading {
            loadingView.animationView.stop()
        }
    }
}

// MARK: Binding
extension UserTweetsViewController {

    private func selectionInput() -> Driver<Int> {
        userTweetsView.tableView.rx
            .itemSelected
            .do(onNext: { self.userTweetsView.tableView.deselectRow(at: $0, animated: true) })
            .map({ $0.row })
            .asDriver(onErrorDriveWith: .empty())
    }

    private func viewDidLoadInput() -> Driver<Void> {
        loadSubject.asDriver()
    }

    private func viewModelInput() -> UserTweetsViewModeling.Input {
        UserTweetsViewModelInput(viewDidLoad: viewDidLoadInput(), selection: selectionInput())
    }

    private func bind() {
        userTweetsView.tableView.rx
            .setDelegate(self)
            .disposed(by: bag)
        let output = viewModel.transform(input: viewModelInput())
        output.didSucceed
            .do(onNext: { self.setSubViewsVisibility(isDataSourceEmpty: $0.isEmpty) })
            .map { [TweetsSection(header: String(), items: $0)] }
            .drive(userTweetsView.tableView.rx.items(dataSource: tableDataSource))
            .disposed(by: bag)
        output.isLoading
            .drive(onNext: {
                self.userTweetsView.isLoading = $0
            }).disposed(by: bag)
        output.isEvaluating
            .drive(onNext: { self.setAnimation(isLoading: $0) })
            .disposed(by: bag)
    }
}

// MARK: UserTweetsViewDelegate
extension UserTweetsViewController: UserTweetsViewDelegate {

    func refresh() {
        loadSubject.accept(())
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 160
    }

    public func tableView(_ tableView: UITableView,
                          heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        view.safeAreaInsets.bottom
    }

    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    public func tableView(_ tableView: UITableView,
                          didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? TweetCell else {
            return
        }
        cell.cancelProfileImageRequest()
    }
}

// MARK: RxTableViewable
extension UserTweetsViewController: RxTableViewable {

    public var cellConfiguration: (TableViewSectionedDataSource<TweetsSection>,
                            UITableView, IndexPath, TweetViewModel) -> TweetCell {
        return { _, tableView, indexPath, viewModel in
            guard let cell = tableView
                .dequeueReusableCell(withIdentifier: TweetCell.identifier,
                                     for: indexPath) as? TweetCell else {
                return TweetCell()
            }
            cell.bind(viewModel: viewModel)
            return cell
        }
    }
}
