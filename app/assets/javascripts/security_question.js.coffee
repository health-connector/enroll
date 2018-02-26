SecurityQuestion =
  Init: ->
    @selectFirstSecurityQuestion()
    @selectSecondSecurityQuestion()
    @selectThirdSecurityQuestion()

  selectFirstSecurityQuestion: ->
    $(document).on 'change', '.security-question-select-1', ->
      if $('.security-question-select-2').val() ==''
        params = [$(@).val(), $('.security-question-select-3').val()]
        $('.question-wrapper-2').load("/users/filter?question_ids=#{params}&index=2")

      if $('.security-question-select-3').val() ==''
        params = [$(@).val(), $('.security-question-select-2').val()]
        $('.question-wrapper-3').load("/users/filter?question_ids=#{params}&index=3")

  selectSecondSecurityQuestion: ->
    $(document).on 'change', '.security-question-select-2', ->
      if $('.security-question-select-1').val() ==''
        params = [$(@).val(), $('.security-question-select-3').val()]
        $('.question-wrapper-1').load("/users/filter?question_ids=#{params}&index=1")

      if $('.security-question-select-3').val() ==''
        params = [$(@).val(), $('.security-question-select-1').val()]
        $('.question-wrapper-3').load("/users/filter?question_ids=#{params}&index=3")

  selectThirdSecurityQuestion: ->
    $(document).on 'change', '.security-question-select-3', ->
      if $('.security-question-select-1').val() ==''
        params = [$(@).val(), $('.security-question-select-2').val()]
        $('.question-wrapper-1').load("/users/filter?question_ids=#{params}&index=1")

      if $('.security-question-select-2').val() ==''
        params = [$(@).val(), $('.security-question-select-1').val()]
        $('.question-wrapper-2').load("/users/filter?question_ids=#{params}&index=2")


$ ->
  SecurityQuestion.Init()