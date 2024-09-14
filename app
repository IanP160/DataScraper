from flask import Flask, request, jsonify
import os
from PyPDF2 import PdfReader
from docx import Document
import openai

app = Flask(__name__)

# Set up your OpenAI API Key
openai.api_key = 'your-openai-api-key'

def extract_text_from_pdf(file_path):
    reader = PdfReader(file_path)
    text_data = []
    for i, page in enumerate(reader.pages):
        text = page.extract_text()
        text_data.append({"page": i + 1, "text": text})
    return text_data

def extract_text_from_docx(file_path):
    doc = Document(file_path)
    text_data = []
    for i, para in enumerate(doc.paragraphs):
        text_data.append({"paragraph": i + 1, "text": para.text})
    return text_data

def find_keywords_in_text(text_data, keywords):
    result = []
    for entry in text_data:
        page_or_para = entry.get('page', entry.get('paragraph', None))
        lines = entry['text'].splitlines()
        for line_num, line in enumerate(lines):
            for keyword in keywords:
                if keyword.lower() in line.lower():
                    result.append({
                        "keyword": keyword,
                        "sentence": line.strip(),
                        "page_or_paragraph": page_or_para,
                        "line": line_num + 1
                    })
    return result

def summarize_content(matches):
    # Generate a summary using OpenAI's API based on the matched sentences
    context = "\n".join([match['sentence'] for match in matches])
    response = openai.Completion.create(
        engine="text-davinci-003",
        prompt=f"Summarize the following content based on the given matches:\n{context}",
        max_tokens=150
    )
    return response.choices[0].text.strip()

@app.route('/upload', methods=['POST'])
def upload_document():
    if 'document' not in request.files:
        return jsonify({'error': 'No document uploaded'}), 400
    
    file = request.files['document']
    file_type = file.filename.split('.')[-1].lower()
    
    if file_type not in ['pdf', 'docx']:
        return jsonify({'error': 'Unsupported file type'}), 400

    # Save the file temporarily
    file_path = os.path.join("uploads", file.filename)
    file.save(file_path)
    
    keywords = request.form.get('keywords', '').split(',')

    # Extract text based on file type
    if file_type == 'pdf':
        text_data = extract_text_from_pdf(file_path)
    elif file_type == 'docx':
        text_data = extract_text_from_docx(file_path)

    # Find keywords and generate summary
    matches = find_keywords_in_text(text_data, keywords)
    summary = summarize_content(matches)
    
    # Cleanup temporary file
    os.remove(file_path)

    return jsonify({'matches': matches, 'summary': summary})

if __name__ == '__main__':
    if not os.path.exists('uploads'):
        os.makedirs('uploads')
    app.run(debug=True)
