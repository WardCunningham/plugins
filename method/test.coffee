method = require './method'

describe 'method plugin', ->

	describe 'parsing', ->

		it 'recognizes numbers', (done) ->
			state =
				item: {text: "123"}
			method.dispatch state, (state) ->
				expect(state.list).to.eql [123]
				done()

		it 'defines values', (done) ->
			state =
				item: {text: "321 abc"}
			method.dispatch state, (state) ->
				expect(state.output.abc).to.be 321
				done()

		it 'retrieves values', (done) ->
			state =
				item: {text: "abc"}
				input: {abc: 456}
			method.dispatch state, (state) ->
				expect(state.list).to.eql [456]
				done()

		it 'computes sums', (done) ->
			state =
				item: {text: "abc\n3000\nSUM xyz"}
				input: {abc: 456}
				output: {}
			method.dispatch state, (state) ->
				console.log 'test state', state
				expect(state.output.xyz).to.be 3456
				done()
