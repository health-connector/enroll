# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'notifier/notice_kinds/index.html.erb', type: :view do
  before do
    assign(:errors, [])
    assign(:datatable, instance_double('Effective::Datatables::NoticesDatatable'))

    allow(view).to receive(:render_datatable).and_return('<div id="notices-datatable"></div>'.html_safe)

    view.singleton_class.define_method(:new_notice_kind_path) { '/notifier/notice_kinds/new' }
    view.singleton_class.define_method(:download_notices_notice_kinds_path) { '/notifier/notice_kinds/download_notices' }
    view.singleton_class.define_method(:upload_notices_notice_kinds_path) { '/notifier/notice_kinds/upload_notices' }

    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:render).with('/ui-components/v1/navs/primary_nav', active_tab: 'home-tab').and_return('<nav id="primary-nav"></nav>'.html_safe)
  end

  it 'renders the tab content wrapper used by remote admin tab navigation' do
    render

    expect(rendered).to have_css('div#inbox > div#tabContent')
  end

  it 'renders notices content inside the tab content wrapper' do
    render

    expect(rendered).to have_css('div#inbox #tabContent .notices_index_list')
  end
end