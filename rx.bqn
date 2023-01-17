#!/usr/bin/env bqn

# TODO need to support error bubbling (would simplify tests...)
future ⇐ {
	# TODO types
	# TODO: add lazy mode
	Eager⇐{ 𝕊 executor:
		pendingListeners←valueBox←⟨⟩
		# TODO Unwrap more eagerly? Also, maybe clean this up a little...
		Dispatch←{cb 𝕊 v: # Unwrap v then pass to cb.
			{
				⟨t⇐then⟩ : v.Then {{cb Dispatch 𝕩}}
			;	CB v
			} v
			@
		}
		Resolver←{𝕊 value:
			Dispatch⟜value¨pendingListeners
			pendingListeners‿valueBox↩⟨⟩‿⟨value⟩
			value
		}
		Executor resolver
		# TODO: Support list of chained callbacks
		# TODO: Have _Then_ modifier instead?
		Then⇐{𝕊 listener :
			Eager {{𝕊 resolve :
				Done←Resolve∘Listener
				{
					  𝕊 ⟨result⟩ : done Dispatch result
					; 𝕊 ⟨⟩     : pendingListeners ∾↩ done
				} valueBox ⋄ @
			}}
		}
	}
	Of⇐{𝕩.then⋄𝕩}⎊{𝕊 v: Eager {{𝕏 v}}}
	never⇐Eager {{𝕤}}
	# TODO make implicit by accepting list in Then...
	Chain⇐(Of @)⊸({𝕨.Then 𝕩}˜´) ⌽

	# TODO race, all...
}

# Async linked lists
empty←future.Of @

Cons⇐{head 𝕊 tail: #⋈
	(future.Of head).Then {{ 𝕩 ⋈ future.Of(tail) }}
}




_ForEach⇐{F _ForEach 𝕩:
	(Of 𝕩).Then {{
		@             : @
	;	⟨value, rest⟩ :
			F value
			F _ForEach rest
	}}
	@
}

# ˘ → ˽ ?
# TODO should act as ˘ for lists
# (And probably more like ¨ instead??)
_Cells⇐{ F _Cells 𝕩:
	(Of 𝕩).Then {{
		@             : @
	;	⟨value, rest⟩ :
		head← F value # Order of evaluation matters here!
		tail← F _Cells rest
		head Cons tail
	}}
}

# ` → ??? (greek lower numeral sign)? 
# TODO make initial value (𝕨) optional
_Scan⇐{ acc Cb _Scan stream:
	{acc↩ acc Cb 𝕩} _Cells stream
}

# TODO think more about eval order...
_Reduce⇐{ acc F _Reduce stream:
	stream.Then {{
		@: acc
	;	 ⟨value, rest⟩: (acc F value) F _Reduce rest
	}}
}

# Procedural interface for building streams.
Signal⇐{𝕊 𝕩:
	res ← @ # "resolve" function for next value
	root←future.Eager {{res↩𝕩}}
	Push←{
		r←@
		Res 𝕩 Cons future.Eager{{R↩𝕏}}
		Res↩R
	}
	Close←{𝕤⋄
		Res @
		res↩@
	}
	𝕏 {push⇐push, close⇐close}
	root
}

## Combining operators ## 
Combine⇐{a 𝕊 b: 
	Signal{{𝕊 push‿close:
		Push _ForEach a
		Push _ForEach b
		future.Chain ⟨
			⊢_Reduce⟜a,
			⊢_Reduce⟜b,
			Close
		⟩
	}}
}

# Operator for two-way data binding.
_BindOld⇐{a XForm _Bind b:  # TODO Clean or rename...
	Signal{{𝕊 push‿close:
		{Push ⟨𝕩, XForm 𝕩⟩} _ForEach a
		{Push ⟨XForm⁼𝕩, 𝕩⟩} _ForEach b
		future.Chain⟨
			⊢_Reduce⟜a,
			⊢_Reduce⟜b,
			Close
		⟩
	}}
}
_Bind⇐{a XForm _Bind b:
	as←a Combine XForm⁼ _Cells b
	bs←b Combine XForm _Cells a   
	⟨as, bs⟩

}
# TODO https://mlochbaum.github.io/BQN/doc/rebqn.html#primitives
# - you can also redefine existing primitives to have time-polymorphism
# - but for now just need a few operators...

rxType ← 983191 # Random number

# Wrap 𝕩 in a stream if it isn't already
# TODO: We should be able to do this without copying the whole dang thing.
# TODO NEXT: This type checking is not strict enough!
Of⇐{
	(future.Of 𝕩).Then {{
		@             : @ 
	;	⟨h, ⟨t⇐then⟩⟩ : 𝕩 # TODO: Terser?
	;	𝕩‿empty 
	}}
}

# I considered replacing builtins with "temporally agnostic"
# replacements... but for that to work we probably need language
# support for blocking async functions (Go style concurrency).
#
# This is probably easier for now anyway.
rxPrimitives⇐⟨
	⟨'ᴗ', _Cells⟩,
	⟨'₍', _Scan⟩,
	⟨'₎', _Reduce⟩,
	⟨'₊', _Bind⟩,
	⟨'⍨', Combine⟩, # analogy: ??
	⟨'⌹', Cons⟩, # analogy: ⋈
⟩
# TODO: Concat

rxbqn ⇐ •ReBQN {
	primitives⇐•primitives∾rxPrimitives
	repl⇐"loose"
	scope⇐"read"
}

# Adapted from https://mlochbaum.github.io/BQN/doc/rebqn.html#primitives
#{
#  # Run on a file
#  0 < ≠•args ?
#    f ← •wdpath •file.At ⊑•args
#    path‿name ← (∧`⌾⌽'/'⊸≠)⊸⊔f
#    ⟨path,name,1↓•args⟩ RxBqn •file.Chars f
#  # Do nothing -- assume imported.
#  ; @
#}
