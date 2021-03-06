require 'spec_helper'

RSpec.describe 'deferred has_and_belongs_to_many associations' do

  before(:example) do
    Person.create!(name: 'Alice')
    Person.create!(name: 'Bob')

    Team.create!(name: 'Database Administration')
    Team.create!(name: 'End-User Support')
    Team.create!(name: 'Operations')

    bob; dba; support; operations
  end

  def bob
    @bob ||= Person.where(name: 'Bob').first
  end

  def dba
    @dba ||= Team.where(name: 'Database Administration').first
  end

  def support
    @support ||= Team.where(name: 'End-User Support').first
  end

  def operations
    @operations ||= Team.where(name: 'Operations').first
  end

  describe 'deferring' do
    it 'does not create a link until parent is saved' do
      bob.teams << dba << support
      expect { bob.save! }.to change { Person.find(bob.id).teams.size }.from(0).to(2)
    end

    it 'does not unlink until parent is saved' do
      bob.team_ids = [dba.id, support.id, operations.id]
      bob.save!

      bob.teams.delete([
        Team.find(dba.id),
        Team.find(operations.id)
      ])

      expect { bob.save }.to change { Person.find(bob.id).teams.size }.from(3).to(1)
    end

    it 'does not create a link when parent is not valid' do
      bob.name = nil # Person.name should be present, Person should not be saved.
      bob.teams << dba

      expect { bob.save }.not_to change { Person.find(bob.id).teams.size }
    end

    it 'replaces existing records when assigning a new set of records' do
      bob.teams = [dba]

      # A mistake was made, Bob belongs to Support and Operations instead.
      bob.teams = [support, operations]

      # The initial assignment of Bob to the DBA team did not get saved, so
      # at this moment Bob is not assigned to any team in the database.
      expect { bob.save }.to change { Person.find(bob.id).teams.size }.from(0).to(2)
    end

    it 'drops nil records' do
      bob.teams << nil
      expect(bob.teams).to be_empty

      bob.teams = [nil]
      expect(bob.teams).to be_empty

      bob.teams.delete(nil)
      expect(bob.teams).to be_empty

      bob.teams.destroy(nil)
      expect(bob.teams).to be_empty
    end

    it 'does not load the deferred associations when saving the parent' do
      _, queries = catch_queries { bob.save! }
      expect(queries.size).to eq(0)
    end

    describe '#collection_singular_ids' do
      it 'returns ids of saved & unsaved associated records' do
        bob.teams = [dba, operations]
        expect(bob.team_ids.size).to eq(2)
        expect(bob.team_ids).to eq [dba.id, operations.id]

        expect { bob.save }.to change { Person.find(bob.id).team_ids.size }.from(0).to(2)

        expect(bob.team_ids.size).to eq(2)
        expect(bob.team_ids).to eq [dba.id, operations.id]
      end
    end

    describe '#collections_singular_ids=' do
      it 'sets associated records' do
        bob.team_ids = [dba.id, operations.id]
        bob.save
        expect(bob.teams).to eq [dba, operations]
        expect(bob.team_ids).to eq [dba.id, operations.id]

        bob.reload
        expect(bob.teams).to eq [dba, operations]
        expect(bob.team_ids).to eq [dba.id, operations.id]
      end

      it 'replace existing records when assigning a new set of ids of records' do
        bob.teams = [dba]

        # A mistake was made, Bob belongs to Support and Operations instead. The
        # teams are assigned through the singular collection ids method. Note
        # that, this also updates the teams association.
        bob.team_ids = [support.id, operations.id]
        expect(bob.teams.length).to eq(2)

        expect { bob.save }.to change { Person.find(bob.id).teams.size }.from(0).to(2)
      end

      it 'clears empty values from the ids to be assigned' do
        bob.team_ids = [dba.id, '']
        expect(bob.teams.length).to eq(1)

        expect { bob.save }.to change { Person.where(name: 'Bob').first.teams.size }.from(0).to(1)
      end

      it 'unlinks all records when assigning empty array' do
        bob.team_ids = [dba.id, operations.id]
        bob.save

        bob.team_ids = []
        expect(bob.teams.length).to eq(0)

        expect { bob.save }.to change { Person.where(name: 'Bob').first.teams.size }.from(2).to(0)
      end

      it 'unlinks all records when assigning nil' do
        bob.team_ids = [dba.id, operations.id]
        bob.save

        bob.team_ids = nil
        expect(bob.teams.length).to eq(0)

        expect { bob.save }.to change { Person.where(name: 'Bob').first.teams.size }.from(2).to(0)
      end
    end

    describe '#collection_checked=' do
      it 'set associated records' do
        bob.teams_checked = "#{dba.id},#{operations.id}"
        expect { bob.save }.to change { Person.where(name: 'Bob').first.teams.size }.from(0).to(2)
      end

      it 'replace existing records when assigning a new set of ids of records' do
        bob.team_ids = [dba.id, operations.id]
        bob.save

        # Replace DBA and Operations by Support.
        bob.teams_checked = "#{support.id}"

        expect{ bob.save }.to change{ Person.where(name: 'Bob').first.teams.size }.from(2).to(1)
        expect(bob.teams.first).to eq(support)
      end

      it 'unlinks all records when assigning empty string' do
        bob.team_ids = [dba.id, operations.id]
        bob.save

        # Unlinks DBA and Operations.
        bob.teams_checked = ""
        expect(bob.teams.length).to eq(0)

        expect{ bob.save }.to change{ Person.where(name: 'Bob').first.teams.size }.from(2).to(0)
      end

      it 'unlinks all records when assigning nil' do
        bob.team_ids = [dba.id, operations.id]
        bob.save

        # Unlinks DBA and Operations.
        bob.teams_checked = nil
        expect(bob.teams.length).to eq(0)

        expect{ bob.save }.to change{ Person.where(name: 'Bob').first.teams.size }.from(2).to(0)
      end
    end

    describe '#changed_for_autosave?' do
      it 'return false if nothing has changed' do
        changed, queries = catch_queries { bob.changed_for_autosave? }
        expect(queries).to be_empty
        expect(changed).to eq(false)
      end

      it 'does not query anything if the objects have not been loaded' do
        bob.name = 'James'
        changed, queries = catch_queries { bob.changed_for_autosave? }
        expect(queries).to be_empty
        expect(changed).to eq(true)
      end

      it 'returns true if there is a pending create' do
        bob.teams = [dba]
        changed, queries = catch_queries { bob.changed_for_autosave? }
        expect(queries).to be_empty
        expect(changed).to eq(true)
      end

      it 'returns true if there is a pending delete' do
        bob.teams = [dba]
        bob.save!

        bob = Person.where(name: 'Bob').first
        bob.teams.delete(dba)
        changed, queries = catch_queries { bob.changed_for_autosave? }
        expect(queries).to be_empty
        expect(changed).to eq(true)
      end

      it 'does not perform any queries if the original association has not been loaded' do
        bob.teams = [dba]
        changed, queries = catch_queries { bob.changed_for_autosave? }
        expect(queries).to be_empty
        expect(changed).to eq(true)
      end
    end
  end

  describe 'validating' do
    xit 'does not add duplicate values' do
      pending 'uniq does not work correctly yet' do
        dba = Team.first
        dba.people = [Person.first, Person.find(2), Person.last]

        expect(dba.people.size).to eq 2
        expect(dba.person_ids).to eq [1,2]
      end
    end

    xit 'deferred habtm <=> regular habtm' do
      alice = Person.where(name: 'Alice').first
      bob = Person.where(name: 'Bob').first

      team = Team.first
      team.people << alice << bob
      team.save!

      bob.reload
      expect(bob.teams.size).to eq(1)

      alice.reload
      expect(alice.teams.size).to eq(1)

      team.people.create!(name: 'Chuck')
      expect(team).to_not be_valid

      bob.reload
      alice.reload

      expect(bob).to_not be_valid
      expect(alice).to_not be_valid

      expect(bob.save).to be_falsey
      expect(alice.save).to be_falsey
    end

    xit 'does not validate records when validate: false' do
      pending 'validate: false does not work' do
        alice = Person.where(name: 'Alice').first
        alice.teams.build(name: nil)
        alice.save!

        expect(alice.teams.size).to eq 1
      end
    end
  end

  describe 'preloading' do
    before do
      bob.teams << dba << support
      bob.save!
    end

    it 'loads the association when pre-loading' do
      person = Person.preload(:teams).where(name: 'Bob').first
      expect(person.teams.loaded?).to be_truthy
      expect(person.team_ids).to eq [dba.id, support.id]
    end

    it 'loads the association when eager loading' do
      person = Person.eager_load(:teams).where(name: 'Bob').first
      expect(person.teams.loaded?).to be_truthy
      expect(person.team_ids).to eq [dba.id, support.id]
    end

    it 'loads the association when joining' do
      person = Person.includes(:teams).where(name: 'Bob').first
      expect(person.teams.loaded?).to be_truthy
      expect(person.team_ids).to eq [dba.id, support.id]
    end

    it 'does not load the association when using a regular query' do
      person = Person.where(name: 'Bob').first
      expect(person.teams.loaded?).to be_falsey
    end
  end

  describe 'reloading' do
    before do
      bob.teams << operations
      bob.save!
    end

    it 'throws away unsaved changes when reloading the parent' do
      # Assign Bob to some teams, but reload Bob before saving. This should
      # remove the unsaved teams from the list of teams Bob is assigned to.
      bob.teams << dba << support
      bob.reload

      expect(bob.teams).to eq [operations]
      expect(bob.teams.pending_creates).to be_empty
    end

    it 'throws away unsaved changes when reloading the association' do
      # Assign Bob to some teams, but reload the association before saving Bob.
      bob.teams << dba << support
      bob.teams.reload

      expect(bob.teams).to eq [operations]
      expect(bob.teams.pending_creates).to be_empty
    end

    it 'loads changes saved on the other side of the association' do
      # The DBA team will add Bob to their team, without him knowing it!
      dba.people << bob

      # Bob does not know about the fact that he has been added to the DBA team.
      expect(bob.teams).to eq [operations]

      # After resetting Bob, the teams are retrieved from the database and Bob
      # finds out he is now also a team-member of team DBA!
      bob.teams.reload
      expect(bob.teams).to eq [operations, dba]
    end
  end

  describe 'resetting' do
    before do
      bob.teams << operations
      bob.save!
    end

    it 'throws away unsaved changes when resetting the association' do
      # Assign Bob to some teams, but reset the association before saving Bob.
      bob.teams << dba << support
      bob.teams.reset

      expect(bob.teams).to eq [operations]
      expect(bob.teams.pending_creates).to be_empty
    end

    it 'loads changes saved on the other side of the association' do
      # The DBA team will add Bob to their team, without him knowing it!
      dba.people << bob

      # Bob does not know about the fact that he has been added to the DBA team.
      expect(bob.teams).to eq [operations]

      # After resetting Bob, the teams are retrieved from the database and Bob
      # finds out he is now also a team-member of team DBA!
      bob.teams.reset
      expect(bob.teams).to eq [operations, dba]
    end
  end

  describe 'supports methods from Ruby Array' do
    describe '#each_index' do
      it 'returns the index of each element in the association' do
        bob.teams << dba << support
        bob.save!

        result = []
        bob.teams.each_index { |i| result << i }
        expect(result).to eq([0, 1])
      end
    end
  end

  describe 'enumerable methods that conflict with ActiveRecord' do
    describe '#select' do
      before do
        bob.teams << dba << support << operations
        bob.save!
      end

      it 'selects specified columns directly from the database' do
        teams = bob.teams.select('name')

        expect(teams.map(&:name)).to eq ['Database Administration', 'End-User Support', 'Operations']
        expect(teams.map(&:id)).to eq [nil, nil, nil]
      end

      it 'calls a block on the deferred associations' do
        teams = bob.teams.select { |team| team.id == 1 }
        expect(teams.map(&:id)).to eq [1]
      end
    end

    describe 'find' do
      # TODO: Write some tests.
    end

    describe 'first' do
      # TODO: Write some tests.
    end
  end

  describe 'callbacks' do
    before(:example) do
      bob = Person.where(name: 'Bob').first
      bob.teams = [Team.find(3)]
      bob.save!
    end

    it 'calls the link callbacks when adding a record using <<' do
      bob = Person.where(name: 'Bob').first
      bob.teams << Team.find(1)

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before linking team 1',
        'After linking team 1'
      ])
    end

    it 'calls the link callbacks when adding a record using push' do
      bob = Person.where(name: 'Bob').first
      bob.teams.push(Team.find(1))

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before linking team 1',
        'After linking team 1'
      ])
    end

    it 'calls the link callbacks when adding a record using append' do
      bob = Person.where(name: 'Bob').first
      bob.teams.append(Team.find(1))

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before linking team 1',
        'After linking team 1'
      ])
    end

    it 'calls the link callbacks when adding a record using build' do
      bob = Person.where(name: 'Bob').first
      bob.teams.build(name: 'Foooo')

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before linking new team',
        'After linking new team'
      ])
    end

    it 'only calls the Rails callbacks when creating a record on the association using create' do
      bob = Person.where(name: 'Bob').first
      bob.teams.create(name: 'HR')

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before adding new team',
        'After adding team 4'
      ])
    end

    it 'only calls the Rails callbacks when creating a record on the association using create!' do
      bob = Person.where(name: 'Bob').first
      bob.teams.create!(name: 'HR')

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before adding new team',
        'After adding team 4'
      ])
    end

    it 'calls the unlink callbacks when removing a record using delete' do
      bob = Person.where(name: 'Bob').first
      bob.teams.delete(Team.find(3))

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before unlinking team 3',
        'After unlinking team 3'
      ])
    end

    it 'calls the unlink callbacks when removing a record using destroy' do
      bob = Person.where(name: 'Bob').first
      bob.teams.destroy(Team.find(3))

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before unlinking team 3',
        'After unlinking team 3'
      ])
    end

    it 'calls the regular Rails callbacks after saving' do
      bob = Person.where(name: 'Bob').first
      bob.teams = [Team.find(1), Team.find(3)]
      bob.save!

      bob = Person.where(name: 'Bob').first
      bob.teams.delete(Team.find(1))
      bob.teams << Team.find(2)
      bob.teams.build(name: 'Service Desk')
      bob.teams.destroy(Team.find(3))
      bob.save!

      expect(bob.audit_log.length).to eq(16)
      expect(bob.audit_log).to eq([
        'Before unlinking team 1', 'After unlinking team 1',
        'Before linking team 2',   'After linking team 2',
        'Before linking new team', 'After linking new team',
        'Before unlinking team 3', 'After unlinking team 3',
        'Before removing team 3',
        'Before removing team 1',
        'After removing team 3',
        'After removing team 1',
        'Before adding team 2',    'After adding team 2',
        'Before adding new team',  'After adding team 4'
      ])
    end
  end

  describe 'links & unlinks (aka pending creates and deletes)' do
    describe 'links' do
      it 'returns newly build records' do
        bob.teams.build(name: 'Service Desk')
        expect(bob.teams.links.size).to eq(1)
      end

      it 'does not return newly created records' do
        bob.teams.create!(name: 'Service Desk')
        expect(bob.teams.links).to be_empty
      end

      it 'returns associated records that need to be linked to parent' do
        bob.teams = [dba]
        expect(bob.teams.links).to eq [dba]
      end

      it 'does not return associated records that already have a link' do
        bob.teams = [dba]
        bob.save!

        bob.teams << operations

        expect(bob.teams.links).to_not include dba
        expect(bob.teams.links).to include operations
      end

      it 'does not return associated records that are to be deleted' do
        bob.teams = [dba, operations]
        bob.save!
        bob.teams.delete(dba)

        expect(bob.teams.links).to be_empty
      end

      it 'does not return a record that has just been removed (and has not been saved)' do
        bob.teams = [dba]
        bob.save!

        bob.teams.delete(dba)
        bob.teams << dba

        expect(bob.teams.unlinks).to be_empty
        expect(bob.teams.links).to be_empty
      end

      it 'does not load the objects if the original association has not been loaded' do
        bob.teams = [dba, operations]
        bob.save!
        bob = Person.where(name: 'Bob').first

        unlinks, queries = catch_queries { bob.teams.links }
        expect(queries).to be_empty
        expect(unlinks).to eq([])
      end
    end

    describe 'unlinks' do
      it 'returns associated records that need to be unlinked from parent' do
        bob.teams = [dba]
        bob.save!
        bob.teams.delete(dba)

        expect(bob.teams.unlinks).to eq [dba]
      end

      it 'returns an empty array when no records are to be deleted' do
        bob.teams = [dba]
        bob.save!

        expect(bob.teams.unlinks).to be_empty
      end

      it 'does not return a record that has just been added (and has not been saved)' do
        bob.teams = [dba]
        bob.teams.delete(dba)

        expect(bob.teams.unlinks).to be_empty
        expect(bob.teams.links).to be_empty
      end

      it 'does not load the objects if the original association has not been loaded' do
        bob.teams = [dba, operations]
        bob.save!
        bob = Person.where(name: 'Bob').first

        unlinks, queries = catch_queries { bob.teams.unlinks }
        expect(queries).to be_empty
        expect(unlinks).to eq([])
      end
    end
  end

  describe 'active record api' do
    # it 'should execute first on deferred association' do
    #   p = Person.first
    #   p.team_ids = [dba.id, support.id, operations.id]
    #   expect(p.teams.first).to eq(dba)
    #   p.save!
    #   expect(Person.first.teams.first).to eq(dba)
    # end

    # it 'should execute last on deferred association' do
    #   p = Person.first
    #   p.team_ids = [dba.id, support.id, operations.id]
    #   expect(p.teams.last).to eq(operations)
    #   p.save!
    #   expect(Person.first.teams.last).to eq(operations)
    # end

    describe '#build' do
      it 'builds a new record' do
        p = Person.first
        p.teams.build(name: 'Service Desk')

        expect(p.teams[0]).to be_new_record
        expect{ p.save }.to change{ Person.first.teams.count }.from(0).to(1)
      end
    end

    describe '#create!' do
      it 'should create a persisted record' do
        p = Person.first
        p.teams.create!(:name => 'Service Desk')
        expect(p.teams[0]).to_not be_new_record
      end

      it 'should automatically save the created record' do
        p = Person.first
        p.teams.create!(:name => 'Service Desk')
        expect(Person.first.teams.size).to eq(1)
        expect{ p.save }.to_not change{ Person.first.teams.count }
      end
    end

    describe '#destroy' do
      context 'when called on has_many association with dependent: :delete_all' do
        it 'destroys the records supplied and removes them from the collection' do
          printer = Issue.create!(subject: 'Printer PRT-001 jammed')
          database = Issue.create!(subject: 'Database server DB-1337 down')
          sandwich = Issue.create!(subject: 'Make me a sandwich!')

          bob.issues << printer << database << sandwich
          bob.save!

          expect {
            bob.issues.destroy(printer)
            bob.save!
          }.to change {
            Person.find(bob.id).issues.size
          }.from(3).to(2)
          expect { Issue.find(printer.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when called on has_many association without dependent: :delete_all' do
        it 'removes the records supplied from the collection' do
          printer = Issue.create!(subject: 'Printer PRT-001 jammed')
          database = Issue.create!(subject: 'Database server DB-1337 down')
          sandwich = Issue.create!(subject: 'Make me a sandwich!')

          bob.other_issues << printer << database << sandwich
          bob.save!

          expect {
            bob.other_issues.destroy(printer)
            bob.save!
          }.to change {
            Person.find(bob.id).other_issues.size
          }.from(3).to(2)
          expect(Issue.find(printer.id)).to eq(printer)
        end
      end

      context 'when called on has_and_belongs_to_many association' do
        it 'removes the records supplied from the collection' do
          bob.teams << dba << operations
          bob.save!

          expect {
            bob.teams.destroy(dba)
            bob.save!
          }.to change {
            Person.find(bob.id).teams.size
          }.from(2).to(1)
          expect(Team.find(dba.id)).to eq(dba)
        end
      end

      it 'returns an array with the removed records' do
        printer = Issue.create!(subject: 'Printer PRT-001 jammed')
        database = Issue.create!(subject: 'Database server DB-1337 down')
        sandwich = Issue.create!(subject: 'Make me a sandwich!')

        bob.issues << printer << database << sandwich
        bob.save!

        expect(bob.issues.destroy(database)).to eq([database])
      end

      it 'accepts Fixnum values' do
        bob.teams << dba << operations
        bob.save!

        expect {
          bob.teams.destroy(dba.id)
          bob.save!
        }.to change {
          Person.find(bob.id).teams.size
        }.from(2).to(1)
      end

      it 'accepts String values' do
        bob.teams << dba << operations
        bob.save!

        expect {
          bob.teams.destroy("#{dba.id}", "#{operations.id}")
          bob.save!
        }.to change {
          Person.find(bob.id).teams.size
        }.from(2).to(0)
      end
    end

    it 'should allow ActiveRecord::QueryMethods' do
      p = Person.first
      p.teams << dba << operations
      p.save!
      expect(Person.first.teams.where(name: 'Operations').first).to eq(operations)
    end

    it 'should find one without loading collection' do
      p = Person.first
      p.teams = [Team.first, Team.find(3)]
      p.save!

      p = Person.first
      _, queries = catch_queries { p.teams }
      expect(queries).to be_empty
      expect(p.teams.loaded?).to eq(false)

      team, queries = catch_queries { p.teams.find(3) }
      expect(queries.size).to eq(1)
      expect(team).to eq(Team.find(3))
      expect(p.teams.loaded?).to eq(false)

      team, queries = catch_queries { p.teams.first }
      expect(queries.size).to eq(1)
      expect(team).to eq(Team.first)
      expect(p.teams.loaded?).to eq(false)

      team, queries = catch_queries { p.teams.last }
      expect(queries.size).to eq(1)
      expect(team).to eq(Team.find(3))
      expect(p.teams.loaded?).to eq(false)
    end
  end
end
