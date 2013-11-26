Ext = window.Ext4 || window.Ext

Ext.require [
  'Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper'
  'Rally.apps.roadmapplanningboard.TimeframePlanningColumn'
  'Rally.apps.roadmapplanningboard.BacklogBoardColumn'
  'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController'
  'Rally.test.apps.roadmapplanningboard.mocks.StoreFixtureFactory'
]

describe 'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController', ->
  helpers
    dragCard: (options) ->
      dragData =
        card: options.sourceColumn.getCards()[options.sourceIndex]
        column: options.sourceColumn

      @recordSaveStub = @stub dragData.card.getRecord(), 'save', () ->
      if options.destColumnDropController.cmp.planRecord
        @planRecordSaveStub = @stub options.destColumnDropController.cmp.planRecord, 'save', () ->

      options.destColumnDropController.onCardDropped dragData, options.destIndex

    _createColumn: (options, shouldRender) ->
      target = 'testDiv' if shouldRender

      options =
        store: Ext.create 'Ext.data.Store',
          extend: 'Ext.data.Store'
          model: Rally.test.mock.data.WsapiModelFactory.getModel 'PortfolioItem/Feature'
          proxy:
            type: 'memory'

          data: options.data

        planRecord: options.plan
        lowestPIType: 'PortfolioItem/Feature'
        timeframeRecord: options.timeframe
        enableCrossColumnRanking: true
        ownerCardboard: {}
        renderTo: target
        contentCell: target
        headerCell: target

      Ext.create 'Rally.apps.roadmapplanningboard.TimeframePlanningColumn', options

  beforeEach ->
    Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper.loadDependencies()

    planStore = Rally.test.apps.roadmapplanningboard.mocks.StoreFixtureFactory.getPlanStoreFixture()
    timeframeStore = Rally.test.apps.roadmapplanningboard.mocks.StoreFixtureFactory.getTimeframeStoreFixture()
    secondFeatureStore = Rally.test.apps.roadmapplanningboard.mocks.StoreFixtureFactory.getSecondFeatureStoreFixture()

    plan = planStore.getById('513617ecef8623df1391fefc')
    features = Rally.context.context.features.primary
    @leftColumnOptions =
      plan: plan
      timeframe: timeframeStore.getById(plan.get('timeframe').id)
      data: Rally.test.mock.ModelObjectMother.getRecords 'PortfolioItemFeature',
        values: features.slice(0,3)
    @leftColumn = @_createColumn(@leftColumnOptions)

    plan = planStore.getById('513617f7ef8623df1391fefd')
    @rightColumnOptions =
      plan: plan
      timeframe: timeframeStore.getById(plan.get('timeframe').id)
      data: Rally.test.mock.ModelObjectMother.getRecords 'PortfolioItemFeature',
        values: features.slice(5,7)
    @rightColumn = @_createColumn(@rightColumnOptions)

    @backlogColumn = Ext.create 'Rally.apps.roadmapplanningboard.BacklogBoardColumn',
      store: secondFeatureStore
      lowestPIType: 'PortfolioItem/Feature'
      enableCrossColumnRanking: true
      ownerCardboard: {}

    @leftColumnDropController = Ext.create 'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController'
    @leftColumnDropController.init(@leftColumn)
    @rightColumnDropController = Ext.create 'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController'
    @rightColumnDropController.init(@rightColumn)
    @backlogColumnDropController = Ext.create 'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController'
    @backlogColumnDropController.init(@backlogColumn)

    @ajaxRequest = @stub Ext.Ajax, 'request', (options) ->
      options.success.call(options.scope)

  afterEach ->
    Deft.Injector.reset()
    @leftColumnDropController?.destroy()
    @rightColumnDropController?.destroy()
    @backlogColumnDropController?.destroy()
    @leftColumn?.destroy()
    @rightColumn?.destroy()
    @backlogColumn?.destroy()

  describe 'when drag and drop is disabled', ->
    it 'should not have a drop target', ->
      column = @_createColumn(@leftColumnOptions, true)
      controller = Ext.create 'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController',
        dragDropEnabled: false
      controller.init(column)
      column.fireEvent('ready')

      expect(controller.dropTarget).toBeUndefined()

  describe 'when drag and drop is enabled', ->
    it 'should have a drop target', ->
      column = @_createColumn(@rightColumnOptions, true)
      controller = Ext.create 'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController',
        dragDropEnabled: true
      controller.init(column)
      column.fireEvent('ready')

      expect(controller.dropTarget).toBeDefined()

    it 'should allow a card to be dropped in the same column and reorder the cards', ->
      cardCountBefore = @leftColumn.getCards().length
      card = @leftColumn.getCards()[2]

      dragData = { card: card, column: @leftColumn }
      @leftColumnDropController.onCardDropped(dragData, 3)

      targetCard = @leftColumn.getCards()[2]
      cardName = card.getRecord().get('name')
      targetCardName = targetCard.getRecord().get('name')

      expect(targetCardName).toBe(cardName)
      expect(cardCountBefore).toBe(@leftColumn.getCards().length)

    it 'should allow a card to be dropped into another column', ->
      leftColumnCardCountBefore = @leftColumn.getCards().length
      rightColumnCardCountBefore = @rightColumn.getCards().length
      card = @leftColumn.getCards()[2]

      dragData = { card: card, column: @leftColumn }
      @rightColumnDropController.onCardDropped(dragData, 0)

      targetCard = @rightColumn.getCards()[0]
      cardName = card.getRecord().get('name')
      targetCardName = targetCard.getRecord().get('name')

      expect(targetCardName).toBe(cardName)
      expect(leftColumnCardCountBefore - 1).toBe(@leftColumn.getCards().length)
      expect(rightColumnCardCountBefore + 1).toBe(@rightColumn.getCards().length)

    it 'should allow a card to be dropped into a backlog column and persist', ->
      saveStub = @stub @leftColumn.planRecord, 'save', (options) ->
        expect(@dirty).toBe true

      leftColumnCardCountBefore = @leftColumn.getCards().length
      card = @leftColumn.getCards()[2]

      expect(_.any(@leftColumn.planRecord.get('features'), (feature) ->
        feature.id == '1002')).toBe true

      dragData = { card: card, column: @leftColumn }
      @backlogColumnDropController.onCardDropped(dragData, 0)

      expect(_.any(@leftColumn.planRecord.get('features'), (feature) ->
        feature.id == '1002')).toBe false
      expect(saveStub.callCount).toBe 1
      expect(@leftColumn.getCards().length).toBe leftColumnCardCountBefore - 1

    it 'should allow a card to be dragged within the backlog column and persist', ->
      [firstCard, secondCard] = @backlogColumn.getCards()
      dragData = { card: @backlogColumn.getCards()[1], column: @backlogColumn }
      @backlogColumnDropController.onCardDropped(dragData, 0)

      expect(@backlogColumn.getCards().length).toBe 2
      expect(@backlogColumn.getCards()[0]).toBe secondCard
      expect(@backlogColumn.getCards()[1]).toBe firstCard

    it 'should allow a card to be moved out of a backlog column and persist', ->
      saveStub = @stub @leftColumn.planRecord, 'save', (options) ->
        expect(@dirty).toBe true
        options.success.call(options.scope)

      leftColumnCardCountBefore = @leftColumn.getCards().length
      card = @backlogColumn.getCards()[0]

      expect(_.any(@leftColumn.planRecord.get('features'), (feature) ->
        feature.id + '' == '1010')).toBe false
      dragData = { card: card, column: @backlogColumn }
      @leftColumnDropController.onCardDropped(dragData, 0)

      expect(_.any(@leftColumn.planRecord.get('features'), (feature) ->
        feature.id + '' == '1010')).toBe true
      expect(saveStub.callCount).toBe 1
      expect(@leftColumn.getCards().length).toBe leftColumnCardCountBefore + 1


    it 'should allow a card to be dropped into another column and persist feature to plan relationship', ->
      leftColumnCardCountBefore = @leftColumn.getCards().length
      rightColumnCardCountBefore = @rightColumn.getCards().length
      card = @leftColumn.getCards()[2]

      expect(_.any(@leftColumn.planRecord.get('features'), (feature) ->
        feature.id + '' == '1002')).toBe true
      expect(_.any(@rightColumn.planRecord.get('features'), (feature) ->
        feature.id + '' == '1002')).toBe false

      dragData = { card: card, column: @leftColumn }
      @rightColumnDropController.onCardDropped(dragData, 0)

      expect(_.any(@leftColumn.planRecord.get('features'), (feature) ->
        feature.id + '' == '1002')).toBe false
      expect(_.any(@rightColumn.planRecord.get('features'), (feature) ->
        feature.id + '' == '1002')).toBe true

      expect(@ajaxRequest.callCount).toBe 1

      expect(@leftColumn.getCards().length).toBe leftColumnCardCountBefore - 1
      expect(@rightColumn.getCards().length).toBe rightColumnCardCountBefore + 1

    it 'should construct correct url when dragging card from plan to plan', ->
      card = @leftColumn.getCards()[2]

      dragData = { card: card, column: @leftColumn }
      @rightColumnDropController.onCardDropped(dragData, 0)

      expect(@ajaxRequest.lastCall.args[0].url).toBe "http://localhost:9999/roadmap/413617ecef8623df1391fabc/plan/#{@leftColumn.planRecord.get('id')}/features/to/#{@rightColumn.planRecord.get('id')}"
      

  describe 'drag and drop ranking', ->
    describe 'ranking within a backlog', ->
      it 'should send rankAbove when card is dragged to top of the column', ->
        @dragCard
          sourceColumn: @backlogColumn
          destColumnDropController: @backlogColumnDropController
          sourceIndex: 1
          destIndex: 0

        expect(@recordSaveStub.lastCall.args[0].params.rankAbove).toContain '1010'

      it 'should send rankBelow when card is dragged lower than top of the column', ->
        @dragCard
          sourceColumn: @backlogColumn
          destColumnDropController: @backlogColumnDropController
          sourceIndex: 0
          destIndex: 2

        expect(@recordSaveStub.lastCall.args[0].params.rankBelow).toContain '1011'

    describe 'ranking within a plan', ->
      it 'should send rankAbove when card is dragged to top of the column', ->
        @dragCard
          sourceColumn: @leftColumn
          destColumnDropController: @leftColumnDropController
          sourceIndex: 1
          destIndex: 0

        expect(@ajaxRequest.lastCall.args[0].params.rankAbove).toContain '1000'

      it 'should send rankBelow when card is dragged lower than top of the column', ->
        @dragCard
          sourceColumn: @leftColumn
          destColumnDropController: @leftColumnDropController
          sourceIndex: 0
          destIndex: 2

        expect(@ajaxRequest.lastCall.args[0].params.rankBelow).toContain '1001'

    describe 'dragging from backlog to plan', ->
      it 'should send rankAbove when card is dragged to top of the column', ->
        @dragCard
          sourceColumn: @backlogColumn
          destColumnDropController: @leftColumnDropController
          sourceIndex: 0
          destIndex: 0

        expect(@planRecordSaveStub.lastCall.args[0].params.rankAbove).toContain '1000'

      it 'should send rankBelow when card is dragged lower than top of the column', ->
        @dragCard
          sourceColumn: @backlogColumn
          destColumnDropController: @leftColumnDropController
          sourceIndex: 0
          destIndex: 3

        expect(@planRecordSaveStub.lastCall.args[0].params.rankBelow).toContain '1002'

    describe 'dragging from plan to plan', ->
      it 'should send rankAbove when card is dragged to top of the column', ->
        @dragCard
          sourceColumn: @leftColumn
          destColumnDropController: @rightColumnDropController
          sourceIndex: 0
          destIndex: 0

        expect(@ajaxRequest.lastCall.args[0].params.rankAbove).toContain '1005'

      it 'should send rankBelow when card is dragged lower than top of the column', ->
        @dragCard
          sourceColumn: @leftColumn
          destColumnDropController: @rightColumnDropController
          sourceIndex: 0
          destIndex: 2

        expect(@ajaxRequest.lastCall.args[0].params.rankBelow).toContain '1006'

    describe 'dragging from plan to backlog', ->
      it 'should send rankAbove when card is dragged to top of the column', ->
        @dragCard
          sourceColumn: @leftColumn
          destColumnDropController: @backlogColumnDropController
          sourceIndex: 0
          destIndex: 0

        expect(@recordSaveStub.lastCall.args[0].params.rankAbove).toContain '1010'

      it 'should send rankBelow when card is dragged lower than top of the column', ->
        @dragCard
          sourceColumn: @leftColumn
          destColumnDropController: @backlogColumnDropController
          sourceIndex: 0
          destIndex: 2

        expect(@recordSaveStub.lastCall.args[0].params.rankBelow).toContain '1011'
