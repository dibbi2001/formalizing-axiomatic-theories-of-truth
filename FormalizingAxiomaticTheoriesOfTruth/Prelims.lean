import Foundation.Logic.Predicate.Language
import Foundation.Logic.Predicate.Term
import Foundation.FirstOrder.Basic.Syntax.Formula
import Foundation.FirstOrder.Basic.Syntax.Rew

open LO
open FirstOrder
/-
# Definitions for the language LPA and L_T
-/
namespace L_T
inductive Func : ℕ → Type where
  | zero : Func 0
  | succ : Func 1
  | add : Func 2
  | mult : Func 2

inductive Rel : ℕ → Type where
  | t : Rel 1
  | eq : Rel 2

def signature : Language where
  Func := Func
  Rel := Rel

/-
# Useful notation
-/
prefix:60 "S" => Semiterm.func Func.succ
prefix:60 "=" => Semiformula.rel Rel.eq
prefix:60 "T" => Semiformula.rel Rel.t
prefix:60 "zero" => Semiterm.func Func.zero
prefix:60 "add" => Semiterm.func Func.add
prefix:60 "times" => Semiterm.func Func.mult


/-
# Some useful terms
-/
def null {n : ℕ}: Semiterm signature ℕ n :=
  zero ![]
def numeral : ℕ → SyntacticTerm signature
  | .zero => zero ![]
  | .succ n => S ![numeral n]

notation "zero" => null

def funToStr {n}: Func n → String
  | .zero => "0"
  | .succ => "S"
  | .add => "+"
  | .mult => "\\times"
instance : ToString (Func n) := ⟨funToStr⟩

def relToStr {n} : Rel n → String
| .t => "T"
| .eq => "="

instance : ToString (Rel n) := ⟨relToStr⟩

def Func_enc : Func k → ℕ
  | .zero => Nat.pair 0 0 + 1
  | .succ => Nat.pair 1 0 + 1
  | .add => Nat.pair 2 0 + 1
  | .mult => Nat.pair 2 1 + 1

def Func_dec : (n : ℕ) → Option (Func k)
  | 0 => none
  | e + 1 =>
    match k with
      | 0 =>
        match e.unpair.2 with
          | 0 => some (Func.zero)
          | _ => none
      | 1 =>
        match e.unpair.2 with
          | 0 => some (Func.succ)
          | _ => none
      | 2 =>
        match e.unpair.2 with
          | 0 => some (Func.add)
          | 1 => some (Func.mult)
          | _ => none
      | _ => none

lemma Func_enc_dec {k : ℕ}: ∀ f : Func k, Func_dec (Func_enc f) = (some f) := by
  intro h
  induction h
  simp [Func_enc,Nat.pair,Func_dec]
  simp [Func_enc,Nat.pair,Func_dec,Nat.unpair,Nat.sqrt,Nat.sqrt.iter]
  simp [Func_enc,Nat.pair,Func_dec,Nat.unpair,Nat.sqrt,Nat.sqrt.iter]
  simp [Func_enc,Nat.pair,Func_dec,Nat.unpair,Nat.sqrt,Nat.sqrt.iter]

instance enc_f (k : ℕ) : Encodable (signature.Func k) where
  encode := Func_enc
  decode := Func_dec
  encodek := Func_enc_dec

def Rel_enc : Rel k → ℕ
  | .t => Nat.pair 1 0 + 1
  | .eq => Nat.pair 2 0 + 1

def Rel_dec : (n : ℕ) → Option (Rel k)
  | 0 => none
  | e + 1 =>
    match k with
      | 1 =>
        match e.unpair.2 with
          | 0 => some .t
          | _ => none
      | 2 =>
        match e.unpair.2 with
          | 0 => some (Rel.eq)
          | _ => none
      | _ => none

lemma Rel_enc_dec {k : ℕ}: ∀ f : Rel k, Rel_dec (Rel_enc f) = (some f) := by
  intro h
  induction h
  simp [Rel_enc,Nat.pair,Rel_dec,Nat.unpair,Nat.sqrt,Nat.sqrt.iter]
  simp [Rel_enc,Nat.pair,Rel_dec,Nat.unpair,Nat.sqrt,Nat.sqrt.iter]

instance enc_r (k : ℕ) : Encodable (signature.Rel k) where
  encode := Rel_enc
  decode := Rel_dec
  encodek := Rel_enc_dec

def contains_T {n : ℕ}: (Semiformula signature ℕ n) → Bool
| .verum => false
| .falsum => false
| .rel .eq _ => false
| .rel .t _ => true
| .nrel .eq _ => false
| .nrel .t _ => true
| .and φ ψ => (contains_T φ) ∨ (contains_T ψ)
| .or φ ψ => (contains_T φ) ∨ (contains_T ψ)
| .all φ => (contains_T φ)
| .ex φ => (contains_T φ)

#eval not true

/-
# Definitions for the PAT theory
-/
namespace PAT
open L_T
infixr:60 " ⇔ " => LogicalConnective.iff
infixr:60 " ⇒ " => Arrow.arrow

def psucc : (Fin 1 → Semiterm signature ξ n) → Semiterm signature ξ n := .func Func.succ

def first_ax : Semiformula signature ℕ 0 :=
 ∀' (∼ (= ![S ![#0],zero]))
def second_ax : SyntacticFormula signature :=
  ∀' ∀' ((= ![S ![#1],S ![#0]]) ⇒ (= ![#1,#0]))
def third_ax : SyntacticFormula signature :=
  ∀' (= ![add ![#0, zero], #0])
def fourth_ax : SyntacticFormula signature :=
  ∀' ∀' (= ![add ![#1, S ![#0]], S ![add ![#1,#0]]])
def fifth_ax : SyntacticFormula signature :=
  ∀' (= ![times ![#0, zero], zero])
def sixth_ax : SyntacticFormula signature :=
  ∀' ∀' ( = ![times ![#1, S ![#0]], add ![ times ![#1,#0],#1]])

def induction_schema (φ : Semiformula signature ℕ 1) : Semiformula signature ℕ 0 :=
  ((φ/[null]) ⋏ (∀' (φ ⇒ φ/[S ![#0]]))) ⇒ ∀' φ
def induction_set (Γ : Semiformula signature ℕ 1 → Prop) : (Semiformula signature ℕ 0) → Prop :=
  fun ψ => ∃ φ : Semiformula signature ℕ 1, Γ φ ∧ ψ = (induction_schema φ)

def axiom_set : Theory signature := {
  first_ax,
  second_ax,
  third_ax,
  fourth_ax,
  fifth_ax,
  sixth_ax
}

example : ∀φ ∈ axiom_set, (not (contains_T φ)) := by
  intro φ
  intro h1
  cases h1 with
  | inl h2 => rw[h2]; rfl
  | inr h1 =>
    cases h1 with
    | inl h1 => rw[h1]; rfl
    | inr h1 =>
      cases h1 with
      | inl h1 => rw[h1]; rfl
      | inr h1 =>
        cases h1 with
        | inl h1 => rw[h1]; rfl
        | inr h1 =>
          cases h1 with
          | inl h1 => rw[h1]; rfl
          | inr h1 =>
            cases h1 with
            | refl => rfl

def lt : Set (Semiformula signature ℕ 0) := Set.univ
def lpa : Set (Semiformula signature ℕ 0) := {φ | ¬ contains_T φ}

notation "ℒₜ" => lt
notation "ℒₚₐ" => lpa

def t_pat : Theory signature := axiom_set ∪ (induction_set Set.univ)
def t_pa : Theory signature := t_pat ∩ lpa

notation "𝐏𝐀𝐓" => t_pat
notation "𝐏𝐀" => t_pa
