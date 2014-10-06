Ext = window.Ext4 || window.Ext

Ext.require ['Rally.ui.cardboard.plugin.CardContentRight']

describe 'Rally.apps.teamboard.TeamBoardCard', ->
  beforeEach ->
    @record = @mom.getRecord 'user'

  afterEach ->
    @card.destroy()

  describe 'color', ->
    helpers
      cardColor: ->
        @card.getEl().down('.artifact-color').getStyle 'background-color'

    it 'should be default color when groupBy not specified', ->
      @createCard()

      expect(@cardColor()).toBe 'rgb(169, 169, 169)'

    it 'should be a hash of the groupBy field value', ->
      @record.set 'Role', 'Developer'

      @createCard groupBy: 'Role'

      expect(@cardColor()).toBe 'rgb(170, 7, 163)'

  describe 'header', ->
    helpers
      cardHeader: ->
        @card.getEl().down '.card-header'

    it 'should show first name and last name in the header', ->
      @createCard()

      expect(@cardHeader().down('.team-member-name').getHTML()).toBe @record.get('FirstName') + ' ' + @record.get('LastName')

    it 'should show refObjectName in the header when user has no first or last name', ->
      @record.set 'FirstName', ''
      @record.set 'LastName', ''

      @createCard()

      expect(@cardHeader().down('.team-member-name').getHTML()).toBe @record.get('_refObjectName')

    it 'should show role in the header', ->
      @createCard()

      expect(@cardHeader().down('.team-member-role').getHTML()).toBe @record.get('Role')

    it 'should not show None role in the header', ->
      @record.set 'Role', 'None'

      @createCard()

      expect(@cardHeader().down('.team-member-role').getHTML()).toBe ''

  describe 'right side', ->
    helpers
      rightSide: ->
        @card.getEl().down '.rui-card-right-side'

    beforeEach ->
      @createCard()

    it 'should have a placeholder for top', ->
      expect(@rightSide().down('.' + Rally.ui.cardboard.plugin.CardContentRight.TOP_SIDE_CLS)).not.toBeNull()

    it 'should have a placeholder for bottom', ->
      expect(@rightSide().down('.' + Rally.ui.cardboard.plugin.CardContentRight.BOTTOM_SIDE_CLS)).not.toBeNull()

  helpers
    createCard: (config) ->
      @card = Ext.create 'Rally.apps.teamboard.TeamBoardCard', Ext.apply
        record: @record
        renderTo: 'testDiv'
      , config
