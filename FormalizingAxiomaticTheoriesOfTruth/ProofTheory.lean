import FormalizingAxiomaticTheoriesOfTruth.Syntax

open FirstOrder
open Language
open Languages

namespace Calculus
  open BoundedFormula
  variable {L : Language}{n : ℕ}{α : Type}
  /- Some notation -/
  notation f " ↑' " n " at "  m => liftAt n m f
  notation f "↑" n => f ↑' n at 0

  /-- Shifts all variable references one down so one is pushed into
  the to-be-bound category -/
  def shift_one_down : ℕ → ℕ ⊕ Fin 1
    | .zero => .inr 0
    | .succ n   => .inl n

  /-- Shifts all free variables (that are not to be bound) up by one-/
  def shift_free_up : ℕ → ℕ ⊕ Fin 0
    | .zero => .inl (.succ .zero)
    | .succ n => .inl (.succ (n + 1))

  /-- Proof that addition is also transitive in BoundedFormula types -/
  def m_add_eq_add_m {m} : BoundedFormula L ℕ (m + n) → BoundedFormula L ℕ (n + m) := by
    rw[add_comm]
    intro h
    exact h
  instance {m} : Coe (BoundedFormula L ℕ (m + n)) (BoundedFormula L ℕ (n + m)) where
    coe := m_add_eq_add_m

  /-- Proof that adding zero als does nothing in BoundedFormula types -/
  def add_zero_does_nothing : BoundedFormula L ℕ (0 + n) → BoundedFormula L ℕ n := by
    intro h
    rw[zero_add] at h
    exact h
  instance : Coe (BoundedFormula L ℕ (0 + n)) (BoundedFormula L ℕ n) where
    coe := add_zero_does_nothing
  instance : Coe (BoundedFormula L ℕ (n + 0)) (BoundedFormula L ℕ (0 + n)) where
    coe := m_add_eq_add_m

  def sent_term_to_formula_term : Term L (Empty ⊕ Fin n) → Term L (ℕ ⊕ Fin n)
      | .var n => match n with
        | .inl _ => .var (.inl Nat.zero)
        | .inr k => .var (.inr k)
      | .func f ts => .func f (fun i => sent_term_to_formula_term (ts i))
  instance : Coe (Term L (Empty ⊕ Fin n)) (Term L (ℕ ⊕ Fin n)) where
    coe := sent_term_to_formula_term
  def bf_empty_to_bf_N : ∀{n}, BoundedFormula L Empty n → BoundedFormula L ℕ n
      | _, .falsum => .falsum
      | _, .equal t₁ t₂ => .equal t₁ t₂
      | _, .rel R ts => .rel R (fun i => ts i)
      | _, .imp f₁ f₂ => .imp (bf_empty_to_bf_N f₁) (bf_empty_to_bf_N f₂)
      | _, .all f => .all (bf_empty_to_bf_N f)
  instance : Coe (Sentence L) (Formula L ℕ) where
    coe := bf_empty_to_bf_N
  def th_to_set_form : Theory L → (Set (Formula L ℕ)) :=
    fun Th : Theory L => bf_empty_to_bf_N '' Th
  instance : Coe (Theory L) (Set (Formula L ℕ)) where
    coe := th_to_set_form

  variable [∀ n, DecidableEq (L.Functions n)][∀p, DecidableEq (L.Relations p)][∀m, DecidableEq (α ⊕ Fin m)]
  /-- Source for parts : https://github.com/FormalizedFormalLogic/Foundation/blob/94d18217bf9b11d3a0b1944424b1e028e50710a3/Foundation/FirstOrder/Basic/Syntax/Formula.lean -/
  def hasDecEq : {n : ℕ} → (f₁ f₂ : BoundedFormula L α n) → Decidable (f₁ = f₂)
    | _, .falsum, f => by
      cases f <;> try { simp; exact isFalse not_false }
      case falsum => apply Decidable.isTrue rfl
    | _, .equal t₁ t₂, .equal t₃ t₄ => decidable_of_iff (t₁ = t₃ ∧ t₂ = t₄) <| by simp
    | _, .equal _ _, .falsum | _, .equal t₁ t₂, .rel _ _ | _, .equal _ _, .imp _ _ | _, .equal _ _, .all _ => .isFalse <| by simp
    | _, @BoundedFormula.rel _ _ _ m f xs, @BoundedFormula.rel _ _ _ n g ys =>
        if h : m = n then
          decidable_of_iff (f = h ▸ g ∧ ∀ i : Fin m, xs i = ys (Fin.cast h i)) <| by
            subst h
            simp [funext_iff]
        else
          .isFalse <| by simp [h]
    | _, .rel _ _, .falsum | _, .rel _ _, .equal _ _ | _, .rel _ _, .imp _ _ | _, .rel _ _, .all _ => .isFalse <| by simp
    | _, .all f₁, f => by
      cases f <;> try { simp; exact isFalse not_false }
      case all f' => simp; exact hasDecEq f₁ f'
    | _, .imp f₁ f₂, f => by
      cases f <;> try { simp; exact isFalse not_false }
      case imp f₁' f₂' =>
        exact match hasDecEq f₁ f₁' with
        | isTrue hp =>
          match hasDecEq f₂ f₂' with
          | isTrue hq  => isTrue (hp ▸ hq ▸ rfl)
          | isFalse hq => isFalse (by simp[hp, hq])
        | isFalse hp => isFalse (by simp[hp])

  instance : DecidableEq (L.Formula ℕ) := hasDecEq

  def shift_finset_up (Δ : Finset (L.Formula ℕ)) : Finset (L.Formula ℕ) :=
    Finset.image (relabel shift_free_up) Δ

  notation Δ"↑"  => shift_finset_up Δ
  notation A"↓" => relabel shift_one_down A

  variable [BEq (Formula L ℕ)][DecidableEq (Formula L ℕ)]

  /-- G3c sequent calculus -/
  inductive Derivation : (Set (Formula L ℕ)) → (Finset (Formula L ℕ)) → (Finset (Formula L ℕ)) → Type _ where
    | tax {Th Γ Δ} (h : ∃f : Formula L ℕ, f ∈ Th ∧ f ∈ Δ) : Derivation Th Γ Δ
    | lax {Th Γ Δ} (h : ∃f, f ∈ Γ ∧ f ∈ Δ) : Derivation Th Γ Δ
    | iax {Th Γ Δ} (t : L.Term (ℕ ⊕ Fin 0)) (h : t =' t ∈ Δ) : Derivation Th Γ Δ
    | i_two_for_one {Th Γ Δ} (S A) (t₁ t₂ : L.Term (ℕ ⊕ Fin 0)) (h₁ : A////[t₁] ∈ S) (h₂ : t₁ =' t₂ ∈ Γ) (d₁ : Derivation Th Γ S) (h₂ : A////[t₁] ∉ Δ) (h₂ : A////[t₂] ∈ Δ) : Derivation Th Γ Δ
    | i_one_for_two {Th Γ Δ} (S A) (t₁ t₂ : L.Term (ℕ ⊕ Fin 0)) (h₁ : A////[t₂] ∈ S) (h₂ : t₁ =' t₂ ∈ Γ) (d₁ : Derivation Th Γ S) (h₂ : A////[t₁] ∉ Δ) (h₂ : A////[t₂] ∈ Δ) : Derivation Th Γ Δ
    | left_conjunction (A B S) {Th Γ Δ} (h₁ : Derivation Th S Δ) (h₂ : A ∈ S) (h₃ : B ∈ S) (h₄ : Γ = (((S \ {A}) \ {B}) ∪ {A ∧' B})): Derivation Th Γ Δ
    | left_disjunction (A B S₁ S₂ S₃) {Th Γ Δ} (h₁ : Derivation Th S₁ Δ) (h₂ : S₁ = S₃ ∪ {A}) (h₃ : Derivation Th S₂ Δ) (h₄ : S₂ = S₃ ∪ {B}) (h₅ : Γ = S₃ ∪ {A ∨' B}) : Derivation Th Γ Δ
    | left_implication (A B S₁ S₂ S₃) {Th Γ Δ} (d₁ : Derivation Th S₁ S₂) (h₁ : S₂ = Δ ∪ {A}) (d₂ : Derivation Th S₃ Δ) (h₂ : S₃ = {B} ∪ S₁) (h₃ : Γ = S₁ ∪ {A ⟹ B}): Derivation Th Γ Δ
    | left_bot {Th Γ Δ} (h : ⊥ ∈ Γ) : Derivation Th Γ Δ
    | left_negation {Th Γ Δ} (A S₁ S₂) (d₁ : Derivation Th S₁ S₂) (h₁ : Γ = S₁ ∪ {∼A}) (h₂ : Δ = S₂ \ {A}) : Derivation Th Γ Δ
    | right_conjunction {Th Γ Δ} (A B S₁ S₂ S₃) (d₁ : Derivation Th Γ S₁) (h₁ : S₁ = S₃ ∪ {A}) (d₂ : Derivation Th Γ S₂) (h₂ : S₂ = S₃ ∪ {B}) (h₃ : Δ = S₃ ∪ {A ∧' B}) : Derivation Th Γ Δ
    | right_disjunction {Th Γ Δ} (A B S) (d₁ : Derivation Th Γ S) (h₁ : Δ = (S \ {A, B}) ∪ {A ∨' B}): Derivation Th Γ Δ
    | right_implication {Th Γ Δ} (A B S₁ S₂ S₃) (d₁ : Derivation Th S₁ S₂) (h₁ : S₁ = {A} ∪ Γ) (h₂ : S₂ = S₃ ∪ {B}) (h₃ : Δ = S₃ ∪ {A ⟹ B}): Derivation Th Γ Δ
    | right_negation {Th Γ Δ} (A S₁ S₂) (d₁ : Derivation Th S₁ S₂) (h₁ : Γ = S₁ \ {A}) (h₂ : Δ = S₂ ∪ {∼A}) : Derivation Th Γ Δ
    | left_forall {Th Γ Δ}  (A : Formula L ℕ) (B) (h₁ : B = A↓) (t S) (d : Derivation Th S Δ) (h₂ : (A/[t]) ∈ S ∧ (∀'B) ∈ S) (h₃ : Γ = S \ {(A/[t])}) : Derivation Th Γ Δ
    | left_exists {Th Γ Δ} (A B) (S₁ : Finset (Formula L ℕ)) (p : B = A↓) (d₁ : Derivation Th ((S₁↑) ∪ {A}) (Δ↑)) (h₁ : Γ = S₁ ∪ {∃' B}) : Derivation Th Γ Δ
    | right_forall {Th Γ Δ} (A B S) (p : B = A↓) (d₁ : Derivation Th (Γ↑) ((S↑) ∪ {A})) (h₁ : Δ = S ∪ {∀'B}) : Derivation Th Γ Δ
    | right_exists {Th Γ Δ} (A : Formula L ℕ) (B t S) (p : B = A↓) (d₁ : Derivation Th Γ (S ∪ {∃'B, A/[t]})) (h₁ : Δ = S ∪ {∃'B}) : Derivation Th Γ Δ
    | cut {Th Γ Δ} (A S₁ S₂ S₃ S₄) (d₁ : Derivation Th S₁ (S₂ ∪ {A})) (d₂ : Derivation Th ({A} ∪ S₃) S₄) (h₁ : Γ = S₁ ∪ S₃) (h₂ : Δ = S₂ ∪ S₄) : Derivation Th Γ Δ

  def emptyFormList : Finset (Formula L ℕ) := ∅

  @[simp]
  def sequent_provable (Th : Set (Formula L ℕ)) (Γ Δ : Finset (Formula L ℕ)) : Prop :=
    Nonempty (Derivation Th Γ Δ)
  notation Th " ⊢ " Γ " ⟶ " Δ => sequent_provable Th Γ Δ

  @[simp]
  def formula_provable (Th : Set (Formula L ℕ)) (f : Formula L ℕ) : Prop :=
    sequent_provable Th emptyFormList {f}
  notation Th " ⊢ " f => formula_provable Th f

  section MetaRules
    variable {L : Language}[∀n, DecidableEq (L.Functions n)][∀n, DecidableEq (L.Relations n)]
    axiom left_weakening : ∀Th : Set (L.Formula ℕ), ∀Γ Δ : Finset (L.Formula ℕ), ∀φ : L.Formula ℕ, (Th ⊢ Γ ⟶ Δ) → (Th ⊢ {φ} ∪ Γ ⟶ Δ)


  end MetaRules
end Calculus

namespace Derivations
open Calculus
open BoundedFormula

variable {L : Language}
[∀ n, DecidableEq (L.Functions n)]
[∀ n, DecidableEq (L.Relations n)]
[DecidableEq (Formula L ℕ)]

def mp_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) :
  Derivation Th {A, A ⟹ B} {B} := by
  have d₁ : Derivation Th {A} {B, A} := by
    apply Derivation.lax
    exact ⟨A, by simp⟩
  have d₂ : Derivation Th {B, A} {B} := by
    apply Derivation.lax
    exact ⟨B, by simp⟩
  apply Derivation.left_implication A B {A} {B, A} {B, A}
  exact d₁
  apply Finset.insert_eq
  exact d₂
  apply Finset.insert_eq
  apply Finset.insert_eq

def right_implication_derivation
  (Th : Set (Formula L ℕ)) (A B Γ : Formula L ℕ)
  (d₁: Derivation Th {Γ, A} {B}) :
  Derivation Th {Γ} {A ⟹ B} := by
  apply Derivation.right_implication A B {Γ, A} {B} ∅
  exact d₁
  rw [Finset.insert_eq]
  rw [Finset.union_comm]
  rw [Finset.empty_union]
  rw [Finset.empty_union]

def conj_intro_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) :
  Derivation Th {A, B} {A ∧' B} := by
  apply Derivation.right_conjunction A B {A} {B} ∅
  apply Derivation.lax ⟨A, by simp⟩
  simp
  apply Derivation.lax ⟨B, by simp⟩
  simp
  simp

def disj_intro_left_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) :
  Derivation Th {A} {A ∨' B} := by
  apply Derivation.right_disjunction A B {A}
  exact Derivation.lax ⟨A, by simp⟩
  simp

def disj_intro_right_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) :
  Derivation Th {B} {A ∨' B} := by
  apply Derivation.right_disjunction A B {B}
  exact Derivation.lax ⟨B, by simp⟩
  simp

def conj_elim_left_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) (h: A ≠ B) :
  Derivation Th {A ∧' B} {A} := by
  apply Derivation.left_conjunction A B {A, B}
  apply Derivation.lax
  simp
  simp
  simp
  simp only [Finset.sdiff_singleton_eq_erase, Finset.erase_insert, Finset.erase_singleton, Finset.empty_union]
  rw [Finset.erase_insert, Finset.erase_singleton, Finset.empty_union]
  simp
  intro h₁
  exact h h₁

def conj_elim_right_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) (h: A ≠ B) :
  Derivation Th {A ∧' B} {B} := by
  apply Derivation.left_conjunction A B {A, B}
  apply Derivation.lax
  simp
  simp
  simp
  simp only [Finset.sdiff_singleton_eq_erase, Finset.erase_insert, Finset.erase_singleton, Finset.empty_union]
  rw [Finset.erase_insert, Finset.erase_singleton, Finset.empty_union]
  simp
  intro h₁
  exact h h₁

def conj_elim_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) (h : A ≠ B) :
  Derivation Th {A ∧' B} {A, B} := by
  apply Derivation.left_conjunction A B {A, B}
  apply Derivation.lax
  simp
  simp
  simp
  simp only [Finset.sdiff_singleton_eq_erase, Finset.erase_insert, Finset.erase_singleton, Finset.empty_union]
  rw [Finset.erase_insert, Finset.erase_singleton, Finset.empty_union]
  simp
  intro h₁
  exact h h₁

def disj_elim_derivation
  (Th : Set (Formula L ℕ)) (A B C: Formula L ℕ)
  (d₁ : Derivation Th {A} {C}) (d₂ : Derivation Th {B} {C}) :
  Derivation Th {A ∨' B} {C} := by
  apply Derivation.left_disjunction A B {A} {B} ∅
  exact d₁
  simp
  exact d₂
  simp
  simp

def excl_mid_derivation
  (Th : Set (Formula L ℕ)) (A : Formula L ℕ) (Δ : Finset (Formula L ℕ)) (h: A ∉ Δ) :
  Derivation Th Δ {A ∨'∼A} := by
  apply Derivation.right_disjunction A ∼A {A, ∼A}
  apply Derivation.right_negation A (Δ ∪ {A}) {A}
  apply Derivation.lax
  simp
  rw [Finset.union_sdiff_cancel_right]
  simp
  exact h
  rfl
  simp

def double_neg_left_derivation
  (Th: Set (Formula L ℕ)) (A : Formula L ℕ) (h : A ≠ ∼A) :
  Derivation Th {∼∼A} {A} := by
  apply Derivation.left_negation ∼A ∅ {A, ∼A}
  apply Derivation.right_negation A {A} {A}
  apply Derivation.lax
  simp
  simp
  rw [Finset.union_comm]
  rw [Finset.insert_eq]
  rw [Finset.union_comm]
  simp
  rw [Finset.insert_sdiff_cancel]
  rw [Finset.not_mem_singleton]
  exact h

def double_neg_right_derivation
  (Th: Set (Formula L ℕ)) (A : Formula L ℕ) (h : A ≠ ∼A) :
  Derivation Th {A} {∼∼A} := by
  apply Derivation.right_negation ∼A {A,∼A} ∅
  apply Derivation.left_negation A {A} {A}
  apply Derivation.lax
  simp
  rw [Finset.union_comm]
  rw [Finset.insert_eq]
  rw [Finset.union_comm]
  simp
  rw [Finset.insert_sdiff_cancel]
  rw [Finset.not_mem_singleton]
  exact h
  rw [Finset.empty_union]

def demorganslaw_first_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) (h₁ : A ≠ B) (h₂ : (A ∧' B) ∉ ({∼A, ∼B} : Finset (L.Formula ℕ))) (h₃ : (A∧'B) ∉ ({∼A∨'∼B} : Finset (L.Formula ℕ))) :
  Derivation Th {∼(A ∧' B)} {∼A ∨' ∼B} := by
  apply Derivation.left_negation (A ∧'B) {} {A ∧'B, ∼A∨'∼B}
  apply Derivation.right_disjunction ∼A ∼B {A ∧'B, ∼A, ∼B}
  apply Derivation.right_negation A {A} {A ∧'B, ∼B}
  apply Derivation.right_negation B {A, B} {A ∧'B}
  apply Derivation.right_conjunction A B {A} {B} ∅
  apply Derivation.lax
  simp
  rw [Finset.empty_union]
  apply Derivation.lax
  simp
  rw [Finset.empty_union]
  rw [Finset.empty_union]
  rw [Finset.insert_sdiff_cancel]
  rw [Finset.not_mem_singleton]
  exact h₁
  rw [Finset.insert_eq]
  rw [Finset.sdiff_singleton_eq_erase]
  simp
  rw [Finset.insert_eq, Finset.insert_eq, Finset.insert_eq]
  rw [Finset.union_assoc]
  rw [Finset.union_comm {∼A} {∼B}]
  rw [Finset.insert_eq]
  rw [Finset.insert_sdiff_cancel]
  exact h₂
  rw [Finset.empty_union]
  rw [Finset.sdiff_singleton_eq_erase]
  simp
  rw [Finset.erase_eq_of_not_mem]
  exact h₃

def demorganslaw_second_derivation
  (Th : Set (Formula L ℕ)) (A B : Formula L ℕ) (h₁ : (∼A∧'∼B) ∉ ({A, B} : Finset (L.Formula ℕ))) (h₂ : (A∨'B) ∉ ({∼A∧'∼B} : Finset (L.Formula ℕ))):
  Derivation Th {∼(A ∨' B)} {∼A ∧' ∼B} := by
  apply Derivation.left_negation (A ∨'B) ∅ {A ∨' B, ∼A ∧' ∼B}
  apply Derivation.right_disjunction A B {∼A ∧' ∼B, A, B}
  apply Derivation.right_conjunction ∼A ∼B {A, B, ∼A} {A, B, ∼B} {A, B}
  apply Derivation.right_negation A {A} {A, B}
  apply Derivation.lax
  simp
  rw [Finset.sdiff_singleton_eq_erase]
  simp
  rw [Finset.insert_eq, Finset.insert_eq, Finset.insert_eq]
  rw [Finset.union_assoc]
  rw [Finset.insert_eq, Finset.insert_eq, Finset.insert_eq]
  rw [Finset.union_assoc]
  apply Derivation.right_negation B {B} {A, B}
  apply Derivation.lax
  simp
  rw [Finset.sdiff_singleton_eq_erase]
  simp
  rw [Finset.insert_eq, Finset.insert_eq, Finset.insert_eq]
  rw [Finset.union_assoc]
  rw [Finset.insert_eq, Finset.insert_eq, Finset.insert_eq]
  rw [Finset.union_assoc]
  rw [Finset.insert_eq, Finset.insert_eq]
  rw [Finset.union_comm]
  rw [Finset.insert_eq]
  rw [Finset.insert_sdiff_cancel]
  rw [Finset.union_comm]
  exact h₁
  rw [Finset.empty_union]
  rw [Finset.sdiff_singleton_eq_erase]
  simp
  rw [Finset.erase_eq_of_not_mem]
  exact h₂

lemma mp : ∀th : Set (Formula L ℕ), ∀(A B : L.Formula ℕ), Nonempty (Derivation th {A, A ⟹ B} {B}) := by
  intro th A B
  apply mp_derivation at th
  apply th at A
  apply A at B
  apply Nonempty.intro B

lemma conj_intro : ∀th : Set (Formula L ℕ), ∀(A B : L.Formula ℕ), Nonempty (Derivation th {A, B} {A ∧' B}) := by
  intro th A B
  apply conj_intro_derivation at th
  apply th at A
  apply A at B
  apply Nonempty.intro B

end Derivations
