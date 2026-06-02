import os
import json
from dotenv import load_dotenv
load_dotenv()
from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit
from anthropic import Anthropic

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'change-this-in-production')
socketio = SocketIO(app, cors_allowed_origins="*")

# Initialize Anthropic client
client = Anthropic()

# Directory for storing conversation JSON files
CONVERSATIONS_DIR = os.path.join(os.path.dirname(__file__), 'conversations')
os.makedirs(CONVERSATIONS_DIR, exist_ok=True)

def get_conversation_path(client_id, question_id):
	safe_client = ''.join(c for c in client_id if c.isalnum() or c == '-')
	safe_question = ''.join(c for c in question_id if c.isalnum() or c in '-_')
	return os.path.join(CONVERSATIONS_DIR, f'{safe_client}__{safe_question}.json')

def load_conversation(client_id, question_id):
	path = get_conversation_path(client_id, question_id)
	if os.path.exists(path):
		with open(path, 'r', encoding='utf-8') as f:
			return json.load(f)
	return []

def save_conversation(client_id, question_id, history):
	path = get_conversation_path(client_id, question_id)
	with open(path, 'w', encoding='utf-8') as f:
		json.dump(history, f, ensure_ascii=False, indent=2)

@app.route('/health', methods=['GET'])
def health():
	return jsonify({'status': 'ok'})

@socketio.on('connect')
def handle_connect():
	print(f'Client connected: {request.sid}')
	emit('connected', {'data': 'Connected to chat server'})

@socketio.on('disconnect')
def handle_disconnect():
	print(f'Client disconnected: {request.sid}')

@socketio.on('get_history')
def handle_get_history(data):
	client_id = data.get('client_id', '')
	question_id = data.get('question_id', '')
	if not client_id or not question_id:
		emit('history_response', {'question_id': question_id, 'history': []})
		return
	history = load_conversation(client_id, question_id)
	visible = [m for m in history if not m.get('content', '').startswith('[SYSTEM CONTEXT]')]
	emit('history_response', {'question_id': question_id, 'history': visible})

@socketio.on('get_all_history')
def handle_get_all_history(data):
	client_id = data.get('client_id', '')
	question_ids = data.get('question_ids', [])
	histories = []
	for question_id in question_ids:
		history = load_conversation(client_id, question_id)
		visible = [m for m in history if not m.get('content', '').startswith('[SYSTEM CONTEXT]')]
		histories.append({'question_id': question_id, 'history': visible})
	emit('history_response', {'histories': histories})

@socketio.on('send_message')
def handle_message(data):
	user_message = data.get('message', '')
	question_context = data.get('question_context', '')
	question_id = data.get('question_id', '')
	client_id = data.get('client_id', '')

	if not user_message:
		emit('error', {'message': 'Empty message', 'question_id': question_id})
		return

	history = load_conversation(client_id, question_id)

	# Add system context if this is the first message
	if len(history) == 0:
		history.append({
			'role': 'user',
			'content': f"[SYSTEM CONTEXT] The question I need help with:\n\n{question_context}"
		})
		history.append({
			'role': 'assistant',
			'content': 'I understand. I have the question and solution available. What would you like help with?'
		})

	# Add user message
	history.append({'role': 'user', 'content': user_message})

	try:
		response = client.messages.create(
			model="claude-haiku-4-5-20251001",
			max_tokens=2000,
			system=f"""You are a helpful tutor. The student is asking about this question:

{question_context}

Help them understand the concept, work through the problem, or clarify their confusion. Be educational and encouraging. Use LaTeX formatting for math (wrap in $ or $$).""",
			messages=history
		)

		assistant_message = response.content[0].text
		history.append({'role': 'assistant', 'content': assistant_message})
		save_conversation(client_id, question_id, history)

		emit('response', {
			'message': assistant_message,
			'question_id': question_id
		})

	except Exception as e:
		error_msg = str(e)
		print(f'Error: {error_msg}')
		emit('error', {'message': f'Error: {error_msg}', 'question_id': question_id})

@socketio.on('clear_conversation')
def handle_clear(data):
	client_id = data.get('client_id', '')
	question_id = data.get('question_id', '')
	path = get_conversation_path(client_id, question_id)
	if os.path.exists(path):
		os.remove(path)
	emit('conversation_cleared', {'question_id': question_id})

if __name__ == '__main__':
	# Check for API key
	if not os.getenv('ANTHROPIC_API_KEY'):
		print('WARNING: ANTHROPIC_API_KEY environment variable not set!')
		print('Set it with: export ANTHROPIC_API_KEY="sk-..."')
	debug_mode = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
	socketio.run(app, host='0.0.0.0', port=5000, debug=debug_mode)
