RSpec.describe 'Download Requests', type: :request do
  before { ENV['STORAGE_HOST'] = 'storage.example.com' }

  context 'when STORAGE_HOST is not set' do
    before do
      ENV['STORAGE_HOST'] = nil
      get '/download/bucket/file.jpeg'
    end

    it { expect(last_response.status).to be 500 }
    it { expect(last_response.body).to eql 'No STORAGE_HOST configured' }
  end

  context 'when file is available' do
    let(:bucket) { 'cool_bucket' }
    let(:image) { File.join('spec', 'fixtures', 'puppy.jpg') }
    let(:headers) do
      {
        'Last-Modified' => 'Sun, 15 Apr 2018 10:50:19 GMT',
        'ETag' => '989817aabd5f2da6a1c77425a348a080'
      }
    end

    # Mocking storage request
    before do
      stub_request(:head, "https://#{ENV['STORAGE_HOST']}/#{bucket}/#{file}")
        .to_return(status: 200, headers: headers).times(1)
      stub_request(:get, "https://#{ENV['STORAGE_HOST']}/#{bucket}/#{file}")
        .to_return(status: 200, headers: headers, body: File.new(image)).times(1)
    end

    context 'with a filename with one extensions' do
      let(:file) { 'best_image.jpeg' }

      context 'when neither filename nor disposition are provided' do
        before { get "/download/#{bucket}/#{file}" }

        it { expect(last_response.status).to be 200 }
        it { expect(last_response.headers['Content-Disposition']).to eql 'attachment; filename="best_image.jpeg"' }
        it { expect(last_response.headers['Content-Type']).to eql 'image/jpeg' }
        it { expect(last_response.headers['Content-Length']).to eql '17037' }
        it { expect(last_response.headers['Last-Modified']).to eql 'Sun, 15 Apr 2018 10:50:19 GMT'}
        it { expect(last_response.headers['ETag']).to eql '989817aabd5f2da6a1c77425a348a080' }

        it 'returns image as body' do
          expect(last_response.body).to eql File.read(image)
        end
      end

      context 'when filename is provided' do
        before { get "/download/#{bucket}/#{file}?filename=new_file" }

        it { expect(last_response.status).to be 200 }
        it { expect(last_response.headers['Content-Disposition']).to eql 'attachment; filename="new_file.jpeg"' }
      end

      context 'when disposition is provided' do
        before { get "/download/#{bucket}/#{file}?disposition=inline" }

        it { expect(last_response.status).to be 200 }
        it { expect(last_response.headers['Content-Disposition']).to eql 'inline; filename="best_image.jpeg"' }
      end

      context 'when filename and disposition are provided' do
        before { get "/download/#{bucket}/#{file}?disposition=inline&filename=new_file" }

        it { expect(last_response.status).to be 200 }
        it { expect(last_response.headers['Content-Disposition']).to eql 'inline; filename="new_file.jpeg"' }
      end

      context 'when filename param includes an extension' do
        before { get "/download/#{bucket}/#{file}?disposition=inline&filename=best_image.jpeg" }

        it { expect(last_response.status).to be 500 }
        it { expect(last_response.body).to eql 'Don\'t include an extension in the filename param' }
      end
    end

    context 'with a filename param with multiple extensions' do
      let(:file) { 'best_archive123456.warc.gz' }

      before { get "/download/#{bucket}/#{file}?disposition=inline&filename=best_archive" }

      it { expect(last_response.status).to be 200 }
      it { expect(last_response.headers['Content-Disposition']).to eql 'inline; filename="best_archive.warc.gz"' }
    end

    context 'with a filename param containing a period' do
      let(:file) { 'best.image123456.jpeg' }

      before { get "/download/#{bucket}/#{file}?disposition=inline&filename=best.image" }

      it { expect(last_response.status).to be 200 }
      it { expect(last_response.headers['Content-Disposition']).to eql 'inline; filename="best.image.jpeg"' }
    end
  end

  context 'when file is not available' do
    before do
      stub_request(:head, "https://#{ENV['STORAGE_HOST']}/bucket/file.jpeg")
        .to_return(status: 404).times(1)
      get '/download/bucket/file.jpeg'
    end

    it { expect(last_response.status).to be 404 }
    it { expect(last_response.body).to eql 'File not found' }
  end

  context 'when storage host returns an error' do
    before do
      stub_request(:head, "https://#{ENV['STORAGE_HOST']}/bucket/file.jpeg")
        .to_return(status: 500).times(1)
      get '/download/bucket/file.jpeg'
    end

    it { expect(last_response.status).to be 400 }
    it { expect(last_response.body).to eql 'Problem retrieving from Ceph' }
  end
end
